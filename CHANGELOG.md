# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.1](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v1.0.0...v1.0.1) (2026-08-06)


### 🐛 Fixes

* bound the azurerm constraint below 5.0 ([#6](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/issues/6)) ([a6ec61f](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/a6ec61f41406981f41c29dee5e885ae4f8310481))

## [1.0.0](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.5.2...v1.0.0) (2026-07-21)


### ⚠ BREAKING CHANGES

* remove rsg creation ([#3](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/issues/3))

### chore

* remove rsg creation ([#3](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/issues/3)) ([4e8210b](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/4e8210ba94d2b3b704a1fd67d484cd014c258da8))

## [0.5.2](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.5.1...v0.5.2) (2026-02-16)


### 🐛 Fixes

* bug: Microsoft.App/environments service delegation ([#27](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/27)) ([9220520](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/9220520227e6580d8ee359feb91695e7ee0b1466))

## [0.5.1](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.5.0...v0.5.1) (2025-09-15)


### 🚀 Features

* enhancement: adding the vnet_id as output ([#25](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/25)) ([a38f875](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/a38f875264d9a08432b687e7177a628e138455c2))
* enhancement: Add tags to private DNS resources ([#24](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/24)) ([f9ce0a7](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/f9ce0a794db0e64babb92fa89a3cbae998f82a2e))

## [0.5.0](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.4.5...v0.5.0) (2025-03-11)


### 🚀 Features

* Add ability to Bring your own IP for NGW ([#23](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/23)) ([d46f07f](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/d46f07f35dd822f3a5d77b21d947f74c83f9a5d2))

## [0.4.5](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.4.4...v0.4.5) (2025-03-10)


### 🐛 Fixes

* bug: Gateway subnet ([#22](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/22)) ([361b25c](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/361b25c5dea3aa7da5d7095c62ad0dbc6a726a26))

## [0.4.4](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.4.3...v0.4.4) (2025-03-03)

## [0.4.3](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.4.2...v0.4.3) (2025-02-25)


### 🐛 Fixes

* bug: fix for simple rules, it was using the wrong reference name for simple ([#19](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/19)) ([c90af31](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/c90af31c95308898e7155213e487c5010e8d6c42))
* add private_endpoint_network_policies for subnets ([#18](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/18)) ([f0f761f](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/f0f761fc6b1d241a779e993f54362beb22f3566d))

## [0.4.2](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.4.1...v0.4.2) (2025-01-30)


### 🚀 Features

* Enhancement: Add the the attribute address_prefixes to the 'subnets' output ([#17](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/17)) ([6502b5a](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/6502b5a2a97ccd9dba0799086bb2edda21bd1180))

## [0.4.1](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.4.0...v0.4.1) (2025-01-20)


### 🐛 Fixes

* bug: Delegation bug ([#14](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/14)) ([32e7b6e](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/32e7b6e97b3990f631fcd4c1b6f086c318a74f16))

## [0.4.0](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.3.4...v0.4.0) (2024-12-19)


### 🚀 Features

* enhancement: default vnet outbound allowed adjustment ([#13](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/13)) ([b29a3cd](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/b29a3cdb47e3a4c506b7875f227772a00e58edab))

## [0.3.4](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.3.3...v0.3.4) (2024-12-11)


### 🐛 Fixes

* bug: add missing fields ([#12](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/12)) ([a01da1c](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/a01da1c3e0bb72ae3b05bd84eeef11372305e617))

## [0.3.3](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.3.2...v0.3.3) (2024-12-05)


### 🚀 Features

* Bastion source ip mod ([#11](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/11)) ([a8d9d98](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/a8d9d98aa3d60b88a62cd20ec46f09e49829ec07))

## [0.3.2](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.3.1...v0.3.2) (2024-12-03)


### 🐛 Fixes

* bug: Security rule defaults ([#10](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/10)) ([47943b2](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/47943b23c411f3ff1e406537741d3296682d0844))

## [0.3.1](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.3.0...v0.3.1) (2024-11-27)


### 🚀 Features

* enhancement: Update outputs.tf ([#9](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/9)) ([37ea22c](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/37ea22c53cc363c8f79f9018b08e47455c59e342))

## [0.3.0](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.2.0...v0.3.0) (2024-11-25)


### 🚀 Features

* Add NSG and NSG rules.  BREAKING ([#8](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/8)) ([1b308fe](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/1b308feb6450f73619b8c7eefaec8b202aa3824f))

## [0.2.0](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/compare/v0.1.0...v0.2.0) (2024-11-12)


### 🚀 Features

* add private_link_service_network_policies_enabled variable ([#6](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/6)) ([5e7daf7](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/5e7daf74030f6ea5faa8b77584bb99fa2dcf8a99))

### 🐛 Fixes

* bug: dependency fix for vnet resource group ([#7](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/7)) ([60b8c89](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/60b8c89be108c0e5d34f6c2a2d8dd0eba329a7c9))

## 0.1.0 (2024-10-07)


### 🚀 Features

* adding first version of the module ([#1](https://github.com/schubergphilis/terraform-azure-mcaf-network/pull/1)) ([a566ad7](https://github.com/schubergphilis-ep/terraform-azure-mcaf-network/commit/a566ad70cff521ab3404850567744947f7a25fa7))
