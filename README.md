# MathTools Offline Swift

Conversão mínima nativa do MathTools Offline para iOS 15, sem Tauri, Python ou dependências externas.

## Incluído

- Calculadora offline em Swift/UIKit.
- Parser de `+`, `-`, `*`, `/`, `^`, parênteses e funções `sqrt`, `abs`, `sin`, `cos`, `tan`, `log`, `ln`.
- Constantes `pi` e `e`.
- Histórico local em memória.
- Exibição textual da expressão em formato LaTeX inicial.

## Build no iPhone

```sh
swiftc -parse-as-library -sdk /var/jb/usr/share/SDKs/iPhoneOS.sdk \
  -target arm64-apple-ios15.0 MathTools.swift \
  -o MathTools.app/MathTools -framework UIKit -framework Foundation
ldid -S MathTools.app/MathTools
```

Esta é a primeira etapa da conversão. O parser é educacional e não substitui o backend SymPy do projeto original.
