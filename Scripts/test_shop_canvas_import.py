import importlib.util
import json
import pathlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('library_import', pathlib.Path(__file__).with_name('import_shop_canvas_library.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LibraryImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name) / 'public'
        (self.root / 'catalog/images').mkdir(parents=True)
        (self.root / 'merchant-assets').mkdir()
        (self.root / 'catalog/images/a.jpg').write_bytes(b'curated-thumbnail')
        (self.root / 'merchant-assets/new.png').write_bytes(b'current-branding')
        self.catalog = {'selectedIds': ['b', 'a'], 'products': [
            self.product('a', True), self.product('b', True), self.product('archive', False),
        ]}
        self.merchants = {'merchants': [
            {'id': 'merchant-exact', 'name': 'Current name', 'wordmarkWhite': './merchant-assets/new.png',
             'wordmark': None, 'logo': None, 'cover': './catalog/images/a.jpg'},
            {'id': 'different-id', 'name': 'Current name', 'logo': 'https://wrong.invalid/logo.png'},
        ]}
        self.depth = {'products': [self.product('depth', False)], 'enrichment': {'a': {'description': 'Enriched exact product'}}}
        self.save()

    def tearDown(self):
        self.temp.cleanup()

    def product(self, identifier, curated):
        return {'id': identifier, 'curated': curated, 'title': identifier, 'brand': 'Brand',
                'group': 'An edit', 'image': './catalog/images/a.jpg',
                'originalImage': 'https://cdn.example.com/original.jpg',
                'url': 'https://shop.example.com/product', 'price': {'amount': 12345, 'currency': 'USD'},
                'merchants': [{'id': 'merchant-exact', 'name': 'Old embedded name', 'logo': 'https://old.invalid/logo.png'}]}

    def save(self):
        for name, value in [('catalog.json', self.catalog), ('merchants.json', self.merchants), ('merchant-depth.json', self.depth)]:
            (self.root / 'catalog' / name).write_text(json.dumps(value))

    def test_curated_selection_order_and_exact_branding_join(self):
        snapshot = module.make_snapshot(self.root)
        self.assertEqual([p['id'] for p in snapshot['products']], ['b', 'a'])
        self.assertEqual(snapshot['merchants'][0]['name'], 'Current name')
        self.assertEqual(snapshot['merchants'][0]['wordmarkWhite'], './merchant-assets/new.png')
        self.assertIsNone(snapshot['merchants'][0]['logo'])
        self.assertEqual(snapshot['approvedHeroes'], [])
        self.assertEqual(snapshot['products'][0]['price'], '123.45')

    def test_enrichment_is_joined_by_exact_source_product_id(self):
        products = module.make_snapshot(self.root)['products']
        self.assertEqual(products[1]['description'], 'Enriched exact product')
        self.assertNotEqual(products[0]['description'], 'Enriched exact product')

    def test_optional_inventory_never_becomes_curated(self):
        snapshot = module.make_snapshot(self.root, include_depth=True)
        self.assertEqual([p['id'] for p in snapshot['products']], ['b', 'a', 'archive', 'depth'])
        self.assertEqual([p['curated'] for p in snapshot['products']], [True, True, False, False])
        self.assertEqual(snapshot['selectedIds'], ['b', 'a'])

    def test_relative_urls_resolve_from_library_root_and_source_is_unchanged(self):
        original = (self.root / 'catalog/catalog.json').read_bytes()
        snapshot = module.make_snapshot(self.root)
        output = pathlib.Path(self.temp.name) / 'native-copy'
        module.publish_snapshot(self.root, output, snapshot)
        self.assertEqual((output / 'catalog/images/a.jpg').read_bytes(), b'curated-thumbnail')
        self.assertFalse((output / 'catalog/catalog/images/a.jpg').exists())
        self.assertEqual((self.root / 'catalog/catalog.json').read_bytes(), original)
        with self.assertRaises(ValueError):
            module.publish_snapshot(self.root, self.root / 'output', snapshot)

    def test_review_assets_and_directory_escape_are_not_publishable(self):
        for value in ['./merchant-review/logo.png', '../outside.png', 'file:///tmp/logo.png',
                      './catalog/../merchant-assets/new.png', 'https://cdn.example.com/merchant-review/logo.png']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                module.asset_path(value, self.root)
        self.merchants['merchants'][0]['cover'] = './merchant-review/cover.jpg'
        self.save()
        snapshot = module.make_snapshot(self.root)
        self.assertIsNone(snapshot['merchants'][0]['cover'])
        self.assertEqual(len(snapshot['warnings']), 1)

    def test_missing_prices_are_not_zero_or_a_guessed_currency(self):
        self.catalog['products'][0]['price'] = None
        self.save()
        product = module.make_snapshot(self.root)['products'][1]
        self.assertEqual((product['price'], product['currency']), ('', ''))

    def test_missing_exact_merchant_id_cannot_fall_back_to_matching_name(self):
        self.catalog['products'][0]['merchants'][0]['id'] = 'missing-id'
        self.save()
        with self.assertRaises(ValueError):
            module.make_snapshot(self.root)


if __name__ == '__main__':
    unittest.main()
