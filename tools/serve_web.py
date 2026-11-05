"""Local preview: python3 tools/serve_web.py [port]."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from functools import partial
import sys
root=Path(__file__).resolve().parents[1]/'build/web'
port=int(sys.argv[1]) if len(sys.argv)>1 else 8765
print(f'Little Harbor: http://127.0.0.1:{port}',flush=True)
ThreadingHTTPServer(('127.0.0.1',port),partial(SimpleHTTPRequestHandler,directory=str(root))).serve_forever()
