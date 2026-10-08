import pathlib
import subprocess
import sys

output = pathlib.Path(sys.argv[1])
output.mkdir(parents=True, exist_ok=True)
objects = [
    b'<< /Type /Catalog /Pages 2 0 R >>',
    b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 200] /Resources << >> >>',
    b'null',
]
for name, encryption in [('plain', b''), ('direct-null', b'/Encrypt null'),
                         ('indirect-null', b'/Encrypt 4 0 R'),
                         ('undefined-reference', b'/Encrypt 99 0 R'),
                         ('wrong-type', b'/Encrypt true')]:
    data = bytearray(b'%PDF-1.4\n')
    offsets = []
    for number, body in enumerate(objects, 1):
        offsets.append(len(data))
        data.extend(str(number).encode() + b' 0 obj\n' + body + b'\nendobj\n')
    xref = len(data)
    data.extend(b'xref\n0 5\n0000000000 65535 f \n')
    for offset in offsets:
        data.extend(f'{offset:010d} 00000 n \n'.encode())
    data.extend(b'trailer\n<< /Size 5 /Root 1 0 R ' + encryption +
                b' >>\nstartxref\n' + str(xref).encode() + b'\n%%EOF\n')
    (output / (name + '.pdf')).write_bytes(data)
subprocess.run(['qpdf', '--check', str(output / 'plain.pdf')], check=True)
for name, extraction in [('encrypted-restricted', 'n'), ('encrypted-permitted', 'y')]:
    subprocess.run(['qpdf', str(output / 'plain.pdf'), '--object-streams=disable',
                    '--encrypt', 'fixture-user', 'fixture-owner', '256',
                    '--extract=' + extraction, '--',
                    str(output / (name + '.pdf'))], check=True)
    subprocess.run(['qpdf', '--password=fixture-user', '--check',
                    str(output / (name + '.pdf'))], check=True)
