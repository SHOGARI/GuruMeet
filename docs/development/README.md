# Development

## ブランチ運用

`main` への直接マージは禁止する。
`main` へ反映できるのは `develop` からの PR のみ。

作業ブランチは `feature/*`、`fix/*`、`bugfix/*`、`hotfix/*` などを使い、PR は `develop` 宛てに作成する。
作業ブランチから `main` への PR は GitHub Actions で失敗する。

