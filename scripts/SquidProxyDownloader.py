#!/usr/bin/python3
'''
  RECOMMENDED TO USE A VIRTUAL ENVIRONMENT.
  
  REQUIREMENT: pip3 install requests beautifulsoup4
  
  "keep_hierarchy" 
    Will maintain the folder structure, I currently have this set to false.
    Scroll to the bottom of the code to remove it if you want to keep the hierarchy.
    Example:
      "DOWNLOAD_PATH/Nintendo/Family Computer Disk System/file.ext"
      
  WARNING!
  This will download every compressed file from the squidproxy website.
'''
import os
import sys
import requests
import urllib.parse

from pathlib import Path
from urllib.request import urlretrieve

from bs4 import BeautifulSoup

def SquidProxyDownloader(baseURL,urlPath=None, downloadPath=None, keep_hierarchy=True):
    
    if downloadPath is None:
        downloadPath = Path(__file__).resolve().parent

    url = baseURL
    if urlPath is not None:
        url += urlPath

    response = requests.get(url)

    if response.status_code != 200:
        print("Status Code: %s" % (response.status_code))
        sys.exit(1)
    
    soup = BeautifulSoup(response.text, 'html.parser')

    table = soup.find('table', id = 'list')

    for td in table.find_all('td', class_='link'):
        link = td.find('a')

        if (link.text == 'Parent directory/'):
            continue
        
        href = urllib.parse.unquote(link['href'])

        if (href.endswith('/')):
            if urlPath is not None:
                href = f"{urlPath}{href}"
            SquidProxyDownloader(
                baseURL=baseURL,
                urlPath=href,
                downloadPath=downloadPath,
                keep_hierarchy=keep_hierarchy
            )
            continue
        
        if keep_hierarchy == True:
            savePath = downloadPath / urlPath
            os.makedirs(name=savePath, mode=0o66, exist_ok=True)
        else:
            savePath = downloadPath
        savePath = savePath / href

        if savePath.exists():
            continue

        try:
            print(f"Downloading: {href}")
            data_file = urllib.parse.quote(f'{urlPath}{href}')
            urlretrieve(f'{baseURL}{data_file}', savePath, displayProgress)
            print(end='\n')
        except KeyboardInterrupt:
            os.remove(savePath) 
            sys.exit(0)

def displayProgress(blocknum, bs, size):
    percent = (blocknum * bs) / size
    done = "#" * int(40 * percent)
    print(f'\r[{done:<40}] {percent:.1%}', end='')

if __name__ == '__main__':
    url = "https://www.squid-proxy.xyz/"
    SquidProxyDownloader(baseURL=url, keep_hierarchy=False)
