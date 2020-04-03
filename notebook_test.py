import dask.distributed as dd
import fiona as fiona_notebook


def remote_fiona_import(*args):
    import fiona as fiona_worker
    return str(fiona_worker.__version__) + str(args)


def square(x):
    return x**2


def test_square():
    client = dd.Client("127.0.0.1:8786")
    futures = client.map(lambda x: x**2, range(10))
    total = client.gather(client.submit(sum, futures))
    assert total == 285, f"Error: total {total} does not equal expected value: 285"
    print("square test complete")


def test_imports():
    client = dd.Client("127.0.0.1:8786")
    futures = client.map(remote_fiona_import, range(10))
    versions = client.gather(futures)
    print(f"remote fiona import test complete - found version {versions[0][:-1]}")


def main():
    test_square()
    test_imports()


if __name__ == "__main__":
    main()
    print('ran all tests successfully')
