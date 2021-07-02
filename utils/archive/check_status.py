import time
import requests
url = "http://www.newsblur.com"


while True:
    start = time.time()
    req = requests.get(url)
    content = req.content
    end = time.time()
    print((" ---> [%s] Retrieved %s bytes - %s %s" % (str(end - start)[:4], len(content), req.status_code, req.reason)))
    time.sleep(5)

