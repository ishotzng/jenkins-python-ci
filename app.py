def greet(name):
    return f"Hello, {name}! Welcome to Jenkins CI/CD."


def add_numbers(a, b):
    return a + b


def main():
    print(greet("DevOps Engineer"))
    print(f"2 + 3 = {add_numbers(2, 3)}")


if __name__ == "__main__":
    main()

