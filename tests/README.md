# tests/ — harness de regressão do engine

`run.sh` extrai as **funções puras de detecção** do `a4ther.sh` e roda-as com mocks
determinísticos do ambiente Android (`have`/`dumpsys`/`pm`), afirmando benigno×malicioso.
Roda em `sh` **e** `dash` (a mesma portabilidade que o Android/`mksh` e o CI exigem).
Sem device, sem root, sem rede.

## Rodar
```sh
sh tests/run.sh        # ou: dash tests/run.sh
A4_ENGINE=/caminho/a4ther.sh sh tests/run.sh   # apontar p/ outro engine
```
Sai `0` se tudo verde; `1` se alguma asserção falhou; `2` se não conseguiu extrair uma função
(renomeada/reformatada — o harness falha LOUD de propósito).

## Por quê existe
Todo falso-positivo histórico do engine só apareceu **em produção, no device, DEPOIS do dano**:
`ksu`↔`journal_checksum` (root-hide falso em todo ext4), `gadget`↔HAL USB MediaTek (Frida falso),
`xposed`↔`system_exposed_libraries` (libs de câmera ArcSoft contadas como CRÍTICO), nanos `999`
contado 6× (bug de dedup). Este harness transforma um FP numa **falha de CI**.

## Cobertura atual
Funções puras extraídas e testadas — a espinha do anti-FP/anti-evasão de proveniência + nome do app:
`is_oem_ns`, `is_oem_preload`, `pkg_label`, `pkg_show`, `_sl_classify`.

## Como estender (regra de ouro: FP achado = teste novo)
- **Achou um FP/FN numa função?** adicione um `ck "descrição" <esperado> "$(func <input benigno/malicioso>)"`.
- **Nova função pura?** adicione a extração `sed -n '/^nome() {/,/^}/p'` + o nome no self-guard + os `ck`.
- **Decisão inline (`case`/`grep`) que não é função?** o caminho certo é **refatorar pra função**
  (ex.: o `tok_grep` planejado no roadmap) e então testá-la aqui — matching inline não é
  testável de forma robusta (o teste viraria uma réplica que envelhece à parte do código).
- **Fixtures end-to-end** (rodar o engine INTEIRO contra um device stubado via PATH-shim + rootfs
  falso, assertando `clean/* → 0 ● ALERTA` e `malicious/* → ≥1`): é o **v2** do harness — maior,
  fica pra um item dedicado.

## CI
`.github/workflows/engine-tests.yml` roda, em cada push/PR que toca `a4ther.sh` ou `tests/`:
`sh -n` + `dash -n`, checagem de LF puro, e `sh tests/run.sh` + `dash tests/run.sh`.
