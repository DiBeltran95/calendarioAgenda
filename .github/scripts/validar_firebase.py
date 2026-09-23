"""Valida el secreto FIREBASE_DART_DEFINES antes de compilar la app móvil.

Formatos que exige el SDK de Firebase (una clave mal formada hace que la app
de iOS se cierre al abrirla). Uso: python3 validar_firebase.py firebase.json
"""
import json
import re
import sys

EJEMPLO = 'Cópialo tal cual de mobile/firebase.json (no de firebase.example.json).'

try:
    with open(sys.argv[1], encoding='utf-8') as f:
        cfg = json.load(f)
except (OSError, ValueError) as e:
    print(f'::error::FIREBASE_DART_DEFINES no es un JSON válido ({e}). {EJEMPLO}')
    sys.exit(1)

sender = str(cfg.get('FIREBASE_SENDER_ID', ''))
reglas = {
    'FIREBASE_PROJECT_ID': (r'[a-z0-9-]{4,40}', 'el ID del proyecto, p. ej. agendaservi'),
    'FIREBASE_SENDER_ID': (r'\d{6,20}', 'solo números (project_number / GCM_SENDER_ID)'),
    'FIREBASE_ANDROID_API_KEY': (r'A[0-9A-Za-z_-]{38}', 'empieza por AIza y tiene 39 caracteres'),
    'FIREBASE_ANDROID_APP_ID': (rf'1:{re.escape(sender)}:android:[0-9a-f]+', f'1:{sender}:android:…'),
    'FIREBASE_IOS_API_KEY': (r'A[0-9A-Za-z_-]{38}', 'empieza por AIza y tiene 39 caracteres'),
    'FIREBASE_IOS_APP_ID': (rf'1:{re.escape(sender)}:ios:[0-9a-f]+', f'1:{sender}:ios:…'),
}

errores = []
for clave, (patron, ayuda) in reglas.items():
    valor = str(cfg.get(clave, ''))
    if not re.fullmatch(patron, valor):
        muestra = (valor[:6] + '…') if len(valor) > 6 else valor
        errores.append(f'{clave} = "{muestra}" ({len(valor)} caracteres): debe ser {ayuda}')

if errores:
    for e in errores:
        print(f'::error::{e}')
    print(f'::error::Corrige el secreto FIREBASE_DART_DEFINES. {EJEMPLO}')
    sys.exit(1)
print('Configuración de Firebase válida.')
