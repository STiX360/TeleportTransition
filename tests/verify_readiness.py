"""Check vanilla spell fixtures and Lua syntax without opening OpenMW."""
import argparse
import ctypes
import os
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def verify_spells(path):
    expected = {'mark': 60, 'recall': 61, 'divine intervention': 62, 'almsivi intervention': 63}
    found = set()
    with path.open('rb') as stream:
        while header := stream.read(16):
            if len(header) != 16:
                raise ValueError('Truncated ESM header')
            tag, size, _, _ = struct.unpack('<4sIII', header)
            payload = stream.read(size)
            if len(payload) != size:
                raise ValueError('Truncated ESM record')
            if tag != b'SPEL':
                continue
            fields = {}
            offset = 0
            while offset < size:
                if offset + 8 > size:
                    raise ValueError('Truncated spell field')
                key, length = struct.unpack_from('<4sI', payload, offset)
                offset += 8
                if offset + length > size:
                    raise ValueError('Truncated spell data')
                fields.setdefault(key, []).append(payload[offset:offset + length])
                offset += length
            name = fields[b'NAME'][0].rstrip(b'\0').decode('cp1252').lower()
            if name not in expected:
                continue
            assert struct.unpack_from('<I', fields[b'SPDT'][0])[0] == 0, name
            effects = [struct.unpack_from('<H', value)[0] for value in fields.get(b'ENAM', [])]
            assert expected[name] in effects, f'Wrong effect for {name}: {effects}'
            found.add(name)
    assert found == set(expected), f'Missing spells: {set(expected) - found}'
    print('PASS: four normal vanilla spells and their teleport/Mark effects')


def verify_lua(engine):
    with os.add_dll_directory(str(engine)):
        lua = ctypes.CDLL(str(engine / 'lua51.dll'))
        lua.luaL_newstate.restype = ctypes.c_void_p
        lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
        lua.lua_tolstring.restype = ctypes.c_char_p
        lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
        lua.lua_close.argtypes = [ctypes.c_void_p]
        state = lua.luaL_newstate()
        if not state:
            raise RuntimeError('Cannot allocate Lua state')
        try:
            for path in sorted((ROOT / 'scripts').rglob('*.lua')):
                if lua.luaL_loadfile(state, os.fsencode(path)):
                    raise RuntimeError(lua.lua_tolstring(state, -1, None).decode())
                lua.lua_settop(state, 0)
        finally:
            lua.lua_close(state)
    print('PASS: production and test Lua syntax, using engine Lua 5.1')
    production = (ROOT / 'TeleportTransition.omwscripts').read_text().splitlines()
    assert production == ['PLAYER: scripts/teleport_transition/player.lua']
    print('PASS: production manifest excludes all test helpers')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', type=Path, default=Path(r'C:\Modlists\POTI\.OpenMW'))
    parser.add_argument('--esm', type=Path,
                        default=Path(r'D:\Steam\steamapps\common\Morrowind\Data Files\Morrowind.esm'))
    args = parser.parse_args()
    verify_spells(args.esm)
    verify_lua(args.engine)
