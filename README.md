# Kamisado

It's just a Kamisado server running on port 55559 and a client connecting to it. Nothing fancy.

Will update this later.

```sh
luarocks install --lua-version=5.1 --tree=system luarocks luajson
luarocks install --lua-version=5.1 --tree=system luarocks lua-ev
luarocks install --lua-version=5.1 --tree=system luarocks lua-websockets
```

Once luajson is installed, /usr/share/lua/5.1/json/decode/util.lua line 97 needs to be patched to use `lpeg.version` instead of `lpeg.version()`.

