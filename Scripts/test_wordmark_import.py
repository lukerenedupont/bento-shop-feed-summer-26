import hashlib
import importlib.util
import json
import pathlib
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('wordmarks', pathlib.Path(__file__).with_name('import_merchant_wordmarks.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WordmarkImportTests(unittest.TestCase):
    def test_review_status_overrides_an_approved_sounding_folder(self):
        self.assertFalse(module.reviewed({'tier': 'launch-approved', 'review': 'pending'}))
        self.assertFalse(module.reviewed({'tier': 'sweep-generated', 'review': 'identity review pending'}))
        self.assertTrue(module.reviewed({'tier': 'approved', 'review': 'approved_prior_strict_batch'}))

    def test_cosmos_ids_use_a_separate_exact_namespace(self):
        self.assertEqual(module.key({'tier': 'cosmos-brands', 'merchant_id': 42}), 'cosmos-profile:42')
        self.assertEqual(module.key({'tier': 'approved', 'merchant_id': 'gid://shopify/Shop/42'}), 'gid://shopify/Shop/42')

    def test_import_uses_exact_profile_metadata_not_display_name(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source = root / 'source/catalog'; source.mkdir(parents=True)
            directory = source / 'merchants.json'
            directory.write_text(json.dumps({'merchants': [
                {'id': 'domain:one.example', 'name': 'Same name', 'curatedBranding': {'sourceProfileId': 42}},
                {'id': 'domain:two.example', 'name': 'Same name'},
            ]}))
            output = root / 'native'; output.mkdir()
            (output / 'snapshot.json').write_text(json.dumps({'merchants': [
                {'id': 'domain:one.example'}, {'id': 'domain:two.example'}], 'products': [], 'groups': []}))
            data = b'image fixture'
            descriptor = {'file': 'wordmarks/cosmos-brands/mark-white.png', 'sha256': hashlib.sha256(data).hexdigest()}
            manifest = {'reuse_permission': 'internal review only', 'wordmarks': [
                {'tier': 'cosmos-brands', 'merchant_id': 42, 'merchant': 'Not a name join',
                 'review': 'cosmos_native_capture_visually_reviewed', 'white': descriptor},
            ]}
            archive = root / 'marks.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('wordmarks/manifest.json', json.dumps(manifest))
                z.writestr(descriptor['file'], data)
            before = directory.read_bytes()
            result = module.import_marks(archive, directory, output)
            self.assertEqual(result['merchantKeys'], {'domain:one.example': 'cosmos-profile:42'})
            self.assertEqual(directory.read_bytes(), before)
            with self.assertRaises(ValueError):
                module.import_marks(archive, directory, source.parent)

    def test_bad_checksums_and_paths_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            archive = root / 'marks.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('wordmarks/approved/mark.png', b'actual')
            with zipfile.ZipFile(archive) as z:
                with self.assertRaises(ValueError):
                    module.extract_asset(z, {'file': 'wordmarks/approved/mark.png', 'sha256': 'wrong'}, root)
                with self.assertRaises(ValueError):
                    module.extract_asset(z, {'file': '../escape.png', 'sha256': 'wrong'}, root)


if __name__ == '__main__':
    unittest.main()
