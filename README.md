# Vaizel G1 oficial — Web/Android

O projeto-fonte Godot está em `GodotSandbox3D/`. **Não é um APK** e **não possui uma rede substituta**.

- **Android sem PC:** leia [`GodotSandbox3D/VAIZEL_ANDROID.md`](GodotSandbox3D/VAIZEL_ANDROID.md), configure GitHub Pages/Actions e abra a versão Web no celular. Para um teste imediato do mesmo robô com física real, [simulador de referência](https://www.humanoidrobots.training/unitree/g1).
- **Política:** ONNX de pesos originais Unitree, hash SHA-256 verificado automaticamente na publicação.
- **Física:** MuJoCo WebAssembly; o Godot é renderer da pose, não o integrador da física do Vaizel.
- **Limites:** não testado ponta-a-ponta neste ambiente, pode precisar de ajustes na build na nuvem; jogadores/Caine permanecem na física Godot, sem contatos dinâmicos mútuos com Vaizel; checkpoint da caminhada não usa imagens.

Uma verificação em Godot Editor Android mostra o estado de execução e permite abrir a demonstração oficial, mas não move o G1 porque o runtime nativo Android não está disponível.
