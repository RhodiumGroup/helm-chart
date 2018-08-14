import dask.distributed as dd

client=dd.Client("localhost:8786")
futures = client.map(lambda x: x**2, range(10))
total = client.gather(client.submit(sum, futures))
assert total == 285, total
print("done")
