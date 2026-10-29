# Validação efetivamente realizada

- `GodotSandbox3D/Tests/validate_structure.py`: 0 erros; cena Vaizel presente e Caine intacto.
- `python3 -m unittest discover -s WebRuntime/tests -v`: 3 testes (arquivo/manifesto/parser MJCF).
- `node --test WebRuntime/tests/test_policy.mjs`: 4 testes de contrato de sensores e motores.
- `node --check WebRuntime/g1_runtime.js`: código JS sintaticamente válido.
- Artefato: ZIP auditável com fontes, export preset Web, GitHub Actions e documentação.

# Validação não realizada

- Download real do ONNX oficial e pacote MuJoCo (acesso HTTP externo do contêiner indisponível).
- Build real de npm/Vite e Godot Web no GitHub Actions.
- Execução de MuJoCo, ONNX e renderização Godot simultaneamente em Android.
- Caminhada equilibrada no mundo do usuário após integrar o cenário.

O pipeline foi criado para gerar logs reais dessas verificações quando executado.
