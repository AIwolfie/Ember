# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

datas = []
datas += collect_data_files('qtawesome')
datas += collect_data_files('ytmusicapi')
datas += collect_data_files('yt_dlp')

hiddenimports = []
hiddenimports += collect_submodules('ember')
hiddenimports += collect_submodules('ytmusicapi')
hiddenimports += collect_submodules('yt_dlp')
hiddenimports += collect_submodules('qtawesome')
hiddenimports += [
    'PyQt6.QtMultimedia',
    'PyQt6.QtNetwork',
    'winrt.windows.foundation',
    'winrt.windows.media',
    'winrt.windows.media.playback',
    'winrt.windows.storage.streams',
    'mutagen',
    'pypresence',
]

a = Analysis(
    ['run_ember.py'],
    pathex=['.'],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'unittest', 'pydoc'],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='Ember',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['ember.ico'],
)
