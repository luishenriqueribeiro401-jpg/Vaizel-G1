# VAIZEL G1 — MITO ZERO, FÍSICA REAL

Atenção: abrir `project.godot` no **Godot Editor para Android** não executa a rede oficial; o editor é nativo e não tem automaticamente os motores MuJoCo WASM e ONNX Runtime. Esta versão não faz o boneco andar de mentira. No editor, o personagem só aparece depois que o runtime estiver rodando na versão Web.

## O que foi implementado

- Mantidos o cenário original, o Caine e o controle móvel.
- `VaizelG1Web.tscn`: representa o corpo que o MuJoCo simula; **o Godot não move suas articulações por animação/cinemática**.
- `WebRuntime/g1_runtime.js`: usa o motor oficial MuJoCo 3.14 WebAssembly, o modelo `g1_12dof.xml` da Unitree e o checkpoint original convertido para ONNX (pesos preservados). 12 torques são calculados a cada 2 ms; uma LSTM recebe 47 observações e gera 12 ações (50 Hz alvo).
- `WebRuntime/prepare_assets.py`: baixa os modelos e malhas da Unitree + ONNX da demonstração de referência, confere o SHA256 e espelha os 3 blocos do mapa em colisões MuJoCo.
- `VaizelOfficialWeb.gd`: recebe poses de corpos físicos por `JavaScriptBridge`; as imagens e movimentos no Godot são um **espelho da física calculada no MuJoCo**, não um segundo solucionador físico.
- Malhas visuais: o Godot obtém a malha triangular compilada do MuJoCo uma por vez; as partes grandes demais ficam como volumes de depuração. **A geometria física continua a oficial**.

## Para quem só possui celular (sem PC)

1. Crie um repositório GitHub **privado ou público**, como preferir, usando o navegador do celular, e envie o conteúdo da **pasta raiz do ZIP** (inclusive `.github/` e `WebRuntime/`).
2. No GitHub, abra `Settings → Pages → Build and deployment → Source` e selecione **GitHub Actions**.
3. Entre na aba `Actions`, escolha **Vaizel G1 oficial** e use `Run workflow` (ou envie uma alteração à branch `main`). O servidor da nuvem prepara o motor Web, baixa a política oficial e exporta o projeto Godot 4.4.1. **Não precisa instalar Python, MuJoCo ou PyTorch no telefone**.
4. Quando a ação terminar com sucesso, abra o endereço disponibilizado em `Settings → Pages` no navegador Chrome/Chromium do Android. O celular executa o WebAssembly e a rede ONNX **localmente no navegador**, após o primeiro download do site.
5. No jogo, procure `POLÍTICA OFICIAL ATIVA`, taxa de inferência e número de passos. Os botões AVANÇAR, VIRAR E/D, PARAR, RESET controlam o comando do robô.

> Se o GitHub Actions apresentar erro ou a política não carregar, o log mostrará em qual etapa falhou. Esta integração ainda não foi executada aqui em um Android real; **é um protótipo experimental**.

## Um limite importante

O MuJoCo substitui a física do **Vaizel** e dos 3 obstáculos estáticos que lhe dizem respeito. Jogador e Caine ainda usam GodotPhysics; colisões dinâmicas do Caine e jogador contra Vaizel **não** são bidirecionalmente sincronizadas entre os motores. Isso precisará de uma migração completa ou de uma ponte robusta. Visão por câmera no Godot é mantida como sensor visual experimental, mas o checkpoint de caminhada oficial é **proprioceptivo**, não usa pixels.

## Fonte e política oficial

- Unitree: https://github.com/unitreerobotics/unitree_rl_gym (BSD-3-Clause)
- Checkpoint original: `deploy/pre_train/g1/motion.pt`, commit `276801e46c5d433564f24658bac64f254b7d2d4b`
- ONNX verificado: https://www.humanoidrobots.training/policies/unitree_g1_walk/policy.onnx
- Hash SHA256: `64451da5909cc03a96fb8e435dc2495217292614466f7628718d60a6cab834fd`
- MuJoCo JS oficial: https://github.com/google-deepmind/mujoco/tree/main/wasm (Apache-2.0)
- ONNX Runtime Web: https://onnxruntime.ai/docs/get-started/with-javascript/web.html (MIT)
- Para testar **imediatamente** a física já comprovada no celular, pressione DEMO REAL na cena ou visite https://www.humanoidrobots.training/unitree/g1 . Essa demonstração externa não contém o cenário do Caine.

## Testes incluídos

```bash
python3 -m unittest discover -s WebRuntime/tests -v
node --check WebRuntime/g1_runtime.js
python3 GodotSandbox3D/Tests/validate_structure.py
```

Tests de verdade que faltam: build em GitHub Actions, carregamento da WASM e ONNX no navegador Android, estabilidade do humanoide e sincronização visual durante muitos minutos. **Não consideramos esses testes aprovados sem executá-los.**
