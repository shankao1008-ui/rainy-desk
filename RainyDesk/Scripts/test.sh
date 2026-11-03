#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TASK_TEST_DIR"' EXIT
swiftc -module-cache-path "$TASK_TEST_DIR/modules" Sources/KeyRules.swift Sources/SoundLibrary.swift Tests/main.swift -o "$TASK_TEST_DIR/rules"
"$TASK_TEST_DIR/rules"
python3 - <<'PY'
from pathlib import Path
import wave, struct
files=list(Path('Resources/Sounds').glob('*/*.wav'))
assert len(files)==118
for p in files:
    with wave.open(str(p)) as w:
        assert w.getnchannels()==1 and w.getsampwidth()==2 and w.getframerate()==44100
        values=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
        assert 0 < max(map(abs,values)) < 32767
        assert abs(values[0])<100 and abs(values[-1])<100
print('Passed 118 WAV format, peak and endpoint checks.')
PY

swiftc -parse-as-library -module-cache-path "$TASK_TEST_DIR/modules" Sources/KeyRules.swift Sources/SoundLibrary.swift Tests/LibraryTests.swift -o "$TASK_TEST_DIR/library"
"$TASK_TEST_DIR/library" Resources/Sounds/voice/letter_0.wav
