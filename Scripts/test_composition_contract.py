#!/usr/bin/env python3
"""Exercise the app's real Swift validator via its CLI, without an app test host.
Build: swift build --package-path Packages/ShopCompositionCore --product composition-check
Optional COMPOSITION_CHECK_COMMAND is a JSON argv array (e.g. a Simulator runner).
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMMAND = json.loads(os.environ.get('COMPOSITION_CHECK_COMMAND', json.dumps([
    str(ROOT / 'Packages/ShopCompositionCore/.build/debug/composition-check')
])))


class CompositionContractTests(unittest.TestCase):
    def check_node(self, node):
        payload = dict(schema='shop-composition/2', assets={'photo': {}}, cards=[dict(
            id='card', root=node, alternates=[], entities={'shoe': {}, 'pants': {}},
            presentation=dict(actionStyle='link', disclosure='none'))])
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json') as f:
            json.dump(payload, f); f.flush()
            return subprocess.run(COMMAND + [f.name], capture_output=True, text=True, timeout=20)

    def test_all_twenty_authored_cards(self):
        result = subprocess.run(COMMAND + [str(ROOT / 'ShopFeedSummer26/NextGeneration20/ng20-compositions.json')],
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Validated 20 cards', result.stdout)

    def test_valid_product(self):
        result = self.check_node(dict(id='card.product', kind='product', role='shoe', productPresentation='tile'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unknown_role_reports_exact_node(self):
        result = self.check_node(dict(id='card.hero', kind='product', role='invented'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('card.hero.role: Unknown role: invented', result.stdout)

    def test_legacy_fields_fail_closed(self):
        for key in ['mode', 'axis', 'fit', 'executableCode']:
            with self.subTest(key=key):
                result = self.check_node(dict(id='card', kind='spacer', **{key: 'arbitrary'}))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Unsupported composition field', result.stdout)

    def test_unknown_typed_value_fails_decoding(self):
        result = self.check_node(dict(id='card', kind='media', asset='photo', mediaFit='stretch'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('decoding failed', result.stdout)

    def test_wrong_primitive_cannot_use_media_options(self):
        result = self.check_node(dict(id='card.item', kind='product', role='shoe', mediaFit='cover'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('card.item.mediaFit/playback', result.stdout)

    def test_weights_and_duplicate_ids(self):
        result = self.check_node(dict(id='card', kind='row', weights=[9], children=[
            dict(id='same', kind='spacer'), dict(id='same', kind='spacer')]))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('card.weights', result.stdout)
        self.assertIn('card.children[1].id', result.stdout)

    def test_swap_keeps_anchor(self):
        result = self.check_node(dict(id='card.pants', kind='product', role='pants', alternatives=['shoe']))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('card.pants.alternatives', result.stdout)

    def test_featured_choices_require_three_options(self):
        options = [dict(id=str(i), title='Option', roles=['shoe'], preview=dict(id=f'preview{i}', kind='spacer'))
                   for i in range(2)]
        result = self.check_node(dict(id='card.choice', kind='choice', layout='featured', options=options,
                                     response=dict(id='response', kind='product', role='$selected')))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('card.choice.layout: Featured choice requires exactly three', result.stdout)

    def test_depth_is_bounded(self):
        node = dict(id='leaf', kind='spacer')
        for i in range(10): node = dict(id=f'level{i}', kind='column', children=[node])
        result = self.check_node(node)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Tree exceeds depth/node budget', result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
