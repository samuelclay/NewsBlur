import random
from unittest import TestCase

from redis_completion.engine import RedisEngine


stop_words = set(['a', 'an', 'the', 'of'])

class RedisCompletionTestCase(TestCase):
    def setUp(self):
        self.engine = self.get_engine()
        self.engine.flush()

    def get_engine(self):
        return RedisEngine(prefix='testac', db=15)

    def store_data(self, id=None):
        test_data = (
            (1, 'testing python'),
            (2, 'testing python code'),
            (3, 'web testing python code'),
            (4, 'unit tests with python'),
        )
        for obj_id, title in test_data:
            if id is None or id == obj_id:
                self.engine.store_json(obj_id, title, {
                    'obj_id': obj_id,
                    'title': title,
                    'secret': obj_id % 2 == 0 and 'derp' or 'herp',
                })

    def sort_results(self, r):
        return sorted(r, key=lambda i:i['obj_id'])

    def test_search(self):
        self.store_data()

        results = self.engine.search_json('testing python')
        self.assertEqual(self.sort_results(results), [
            {'obj_id': 1, 'title': 'testing python', 'secret': 'herp'},
            {'obj_id': 2, 'title': 'testing python code', 'secret': 'derp'},
            {'obj_id': 3, 'title': 'web testing python code', 'secret': 'herp'},
        ])

        results = self.engine.search_json('test')
        self.assertEqual(self.sort_results(results), [
            {'obj_id': 1, 'title': 'testing python', 'secret': 'herp'},
            {'obj_id': 2, 'title': 'testing python code', 'secret': 'derp'},
            {'obj_id': 3, 'title': 'web testing python code', 'secret': 'herp'},
            {'obj_id': 4, 'title': 'unit tests with python', 'secret': 'derp'},
        ])

        results = self.engine.search_json('unit')
        self.assertEqual(results, [
            {'obj_id': 4, 'title': 'unit tests with python', 'secret': 'derp'},
        ])

        results = self.engine.search_json('')
        self.assertEqual(results, [])

        results = self.engine.search_json('missing')
        self.assertEqual(results, [])

    def test_boosting(self):
        test_data = (
            (1, 'test alpha', 't1'),
            (2, 'test beta', 't1'),
            (3, 'test gamma', 't1'),
            (4, 'test delta', 't1'),
            (5, 'test alpha', 't2'),
            (6, 'test beta', 't2'),
            (7, 'test gamma', 't2'),
            (8, 'test delta', 't2'),
            (9, 'test alpha', 't3'),
            (10, 'test beta', 't3'),
            (11, 'test gamma', 't3'),
            (12, 'test delta', 't3'),
        )
        for obj_id, title, obj_type in test_data:
            self.engine.store_json(obj_id, title, {
                'obj_id': obj_id,
                'title': title,
            }, obj_type)

        def assertExpected(results, id_list):
            self.assertEqual([r['obj_id'] for r in results], id_list)

        results = self.engine.search_json('alp')
        assertExpected(results, [1, 5, 9])

        results = self.engine.search_json('alp', boosts={'t2': 1.1})
        assertExpected(results, [5, 1, 9])

        results = self.engine.search_json('test', boosts={'t3': 1.5, 't2': 1.1})
        assertExpected(results, [9, 10, 12, 11, 5, 6, 8, 7, 1, 2, 4, 3])

        results = self.engine.search_json('alp', boosts={'t1': 0.5})
        assertExpected(results, [5, 9, 1])

        results = self.engine.search_json('alp', boosts={'t1': 1.5, 't3': 1.6})
        assertExpected(results, [9, 1, 5])

        results = self.engine.search_json('alp', boosts={'t3': 1.5, '5': 1.6})
        assertExpected(results, [5, 9, 1])

    def test_autoboost(self):
        self.engine.store('t1', 'testing 1')
        self.engine.store('t2', 'testing 2')
        self.engine.store('t3', 'testing 3')
        self.engine.store('t4', 'testing 4')
        self.engine.store('t5', 'testing 5')

        def assertExpected(results, id_list):
            self.assertEqual(results, ['testing %s' % i for i in id_list])

        results = self.engine.search('testing', autoboost=True)
        assertExpected(results, [1, 2, 3, 4, 5])

        self.engine.boost('t3')
        results = self.engine.search('testing', autoboost=True)
        assertExpected(results, [3, 1, 2, 4, 5])

        self.engine.boost('t2')
        results = self.engine.search('testing', autoboost=True)
        assertExpected(results, [2, 3, 1, 4, 5])

        self.engine.boost('t1', negative=True)
        results = self.engine.search('testing', autoboost=True)
        assertExpected(results, [2, 3, 4, 5, 1])

        results = self.engine.search('testing', boosts={'t5': 4.0}, autoboost=True)
        assertExpected(results, [5, 2, 3, 4, 1])

        results = self.engine.search('testing', boosts={'t3': 1.5}, autoboost=True)
        assertExpected(results, [3, 2, 4, 5, 1])

    def test_limit(self):
        self.store_data()

        results = self.engine.search_json('testing', limit=1)
        self.assertEqual(results, [
            {'obj_id': 1, 'title': 'testing python', 'secret': 'herp'},
        ])

    def test_filters(self):
        self.store_data()

        f = lambda i: i['secret'] == 'herp'
        results = self.engine.search_json('testing python', filters=[f])

        self.assertEqual(self.sort_results(results), [
            {'obj_id': 1, 'title': 'testing python', 'secret': 'herp'},
            {'obj_id': 3, 'title': 'web testing python code', 'secret': 'herp'},
        ])

    def test_simple(self):
        self.engine.print_scores = True
        self.engine.store('testing python')
        self.engine.store('testing python code')
        self.engine.store('web testing python code')
        self.engine.store('unit tests with python')

        results = self.engine.search('testing')
        self.assertEqual(results, ['testing python', 'testing python code', 'web testing python code'])

        results = self.engine.search('code')
        self.assertEqual(results, ['testing python code', 'web testing python code'])

    def test_correct_sorting(self):
        strings = []
        for i in range(26):
            strings.append('aaaa%s' % chr(i + ord('a')))
            if i > 0:
                strings.append('aaa%sa' % chr(i + ord('a')))

        random.shuffle(strings)

        for s in strings:
            self.engine.store(s)

        results = self.engine.search('aaa')
        self.assertEqual(results, sorted(strings))

        results = self.engine.search('aaa', limit=30)
        self.assertEqual(results, sorted(strings)[:30])

    def test_removing_objects(self):
        self.store_data()

        self.engine.remove(1)

        results = self.engine.search_json('testing')
        self.assertEqual(self.sort_results(results), [
            {'obj_id': 2, 'title': 'testing python code', 'secret': 'derp'},
            {'obj_id': 3, 'title': 'web testing python code', 'secret': 'herp'},
        ])

        self.store_data(1)
        self.engine.remove(2)

        results = self.engine.search_json('testing')
        self.assertEqual(self.sort_results(results), [
            {'obj_id': 1, 'title': 'testing python', 'secret': 'herp'},
            {'obj_id': 3, 'title': 'web testing python code', 'secret': 'herp'},
        ])

    def test_clean_phrase(self):
        self.assertEqual(self.engine.clean_phrase('abc def ghi'), ['abc', 'def', 'ghi'])

        self.assertEqual(self.engine.clean_phrase('a A tHe an a'), [])
        self.assertEqual(self.engine.clean_phrase(''), [])

        self.assertEqual(
            self.engine.clean_phrase('The Best of times, the blurst of times'),
            ['best', 'times', 'blurst', 'times'])

    def test_exists(self):
        self.assertFalse(self.engine.exists('test'))
        self.engine.store('test')
        self.assertTrue(self.engine.exists('test'))

    def test_removing_objects_in_depth(self):
        # want to ensure that redis is cleaned up and does not become polluted
        # with spurious keys when objects are removed
        redis_client = self.engine.client
        prefix = self.engine.prefix

        initial_key_count = len(redis_client.keys())

        # store the blog "testing python"
        self.store_data(1)

        # see how many keys we have in the db - check again in a bit
        key_len = len(redis_client.keys())

        self.store_data(2)
        key_len2 = len(redis_client.keys())

        self.assertTrue(key_len != key_len2)
        self.engine.remove(2)

        # back to the original amount of keys
        self.assertEqual(len(redis_client.keys()), key_len)

        self.engine.remove(1)
        self.assertEqual(len(redis_client.keys()), initial_key_count)

    def test_updating(self):
        self.engine.store('id1', 'title one', 'd1', 't1')
        self.engine.store('id2', 'title two', 'd2', 't2')
        self.engine.store('id3', 'title three', 'd3', 't3')

        results = self.engine.search('tit')
        self.assertEqual(results, ['d1', 'd3', 'd2'])

        # overwrite the data for id1
        self.engine.store('id1', 'title one', 'D1', 't1')

        results = self.engine.search('tit')
        self.assertEqual(results, ['D1', 'd3', 'd2'])

        # overwrite the data with a new title, will remove the title one refs
        self.engine.store('id1', 'Herple One', 'done', 't1')

        results = self.engine.search('tit')
        self.assertEqual(results, ['d3', 'd2'])

        results = self.engine.search('her')
        self.assertEqual(results, ['done'])

        self.engine.store('id1', 'title one', 'Done', 't1', False)
        results = self.engine.search('tit')
        self.assertEqual(results, ['Done', 'd3', 'd2'])

        # this shows that when we don't clean up crap gets left around
        results = self.engine.search('her')
        self.assertEqual(results, ['Done'])
