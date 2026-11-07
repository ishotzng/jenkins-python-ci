import unittest

from app import greet, add_numbers


class TestApp(unittest.TestCase):

    def test_greet(self):
        result = greet("Ishotz")
        self.assertEqual(
            result,
            "Hello, Ishotz! Welcome to Jenkins CI/CD."
        )

    def test_add_numbers(self):
        result = add_numbers(2, 3)
        self.assertEqual(result, 5)

    def test_add_negative_numbers(self):
        result = add_numbers(-2, -3)
        self.assertEqual(result, -5)


if __name__ == "__main__":
    unittest.main()
