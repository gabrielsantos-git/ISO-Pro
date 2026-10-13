# Blackmagic Camera — análise de funcionalidades e plano do ISO-Pro

Status: **fase 1 concluída (fontes públicas)**, **fase 2 pendente (análise binária com REA)**.
Data: 2026-10-13. App de referência: Blackmagic Camera for Android 3.5
(`com.blackmagicdesign.android.blackmagiccam`) e a versão iOS como comparação.

> Regra de sala limpa: este documento registra *o que* o app faz e *quais APIs
> de plataforma* parece usar. Nada de código, strings, ícones ou layouts copiados.

---

## 1. Método e qualidade da evidência

| Fonte | Situação |
|---|---|
| Notícias e changelogs (CineD, PetaPixel, Newsshooter, NoFilmSchool, PRONEWS, RedShark, GSMArena, PhoneArena) | Lidas via busca. Boa cobertura de 1.0 → 3.5 |
| Site oficial / tech specs da Blackmagic | Só trechos indexados. O ambiente bloqueia o acesso direto |
| Análise binária do APK com REA | **Não feita.** O ambiente bloqueia Play Store e espelhos de APK; os motores do REA (apktool + jadx) estão instalados e validados |

### Registro de tentativas de análise binária
| Data | Arquivo | SHA-256 | Resultado REA |
|---|---|---|---|
| 2026-10-13 | `uptodown-com.blackmagicdesign.android.blackmagiccam.apk` (14,8 MB) | `dc885921…b342550` | **Não é o app alvo.** `decode_android_resources`: pacote `com.uptodown` 7.41 (instalador da loja Uptodown), assinado por *Uptodown Technologies SL*. `search_android_classes "blackmagic"`: 0 de 13.961 classes; nenhum APK embutido. Descartado |
| 2026-10-13 | `blackmagic-camera.apk` (19,1 MB) | `188bbdb8…13acdb8`[^1] | **Não é o app alvo.** `inspect_android_package`: pacote `cm.aptoide.pt` 9.22.5.3 (instalador da loja Aptoide), certificado sem organização (`ST=Portugal`). 0 ocorrências de "blackmagic" nos 3 DEX. Descartado |

Requisitos para o próximo arquivo: pacote `com.blackmagicdesign.android.blackmagiccam`; se vier
do Play (split APKs), trazer `base.apk` e todos os `split_*.apk`. O `.apkm` do APKMirror (`3.5.0.0064`) é o formato esperado.

[^1]: SHA-256 completo `188bbdb899be2da401ac0471ba4d10693612fa1067f2ea0987cc6e1afcfd4374`.

Cada linha abaixo tem um nível de confiança: **C** = confirmado por fonte oficial
ou várias fontes, **P** = provável (uma fonte, ou só iOS), **?** = não confirmado.

## 2. Inventário de funcionalidades

### 2.1 Captura de vídeo
| Recurso | Android | iOS | Conf. |
|---|---|---|---|
| H.264 / H.265 (HEVC) | ✓ | ✓ | C |
| Apple ProRes 422 HQ/422/LT/Proxy | ✗ (nenhuma fonte confirma) | ✓ | P |
| ProRes RAW (só em disco externo) | ✗ | ✓ | P |
| Até 8K (depende do sensor: S23 Ultra 8K, Pixel 8 Pro 4K) | ✓ | ✓ | C |
| Rec.709, HLG10; log do fabricante (Oppo O-Log2 na 3.5); Apple Log no iOS | ✓ | ✓ | C |
| 120/240 fps em Sony Xperia (2.0) | ✓ | — | C |
| Proxy HD gravado junto com o original | ✓ | ✓ | C |
| Gravação contínua com pausa (3.4) | ✓ | ? | C |
| Estabilização Off/Standard/Cinematic/Extreme | ? | ✓ | P |
| Desqueeze anamórfico 1.33/1.55 | ? | ✓ | P |

### 2.2 Controles manuais
ISO, velocidade **e ângulo** de obturador, WB em Kelvin + tint, frame rate,
foco manual com **3 presets de foco e rack automático com tempo ajustável**,
zoom com presets até 8x, troca de lente (wide/ultra/tele), suporte a
Blackmagic Focus & Zoom Demand (3.4). Conf. **C**.

### 2.3 Monitoramento
| Recurso | Conf. |
|---|---|
| Zebra (listras diagonais) | C |
| False color (rosa = pele ideal, verde = pele escura, vermelho = estouro) | C |
| Focus peaking | C |
| Histograma, medidores de áudio, guias de enquadramento, grades | C |
| Waveform / vectorscope | **? — sem evidência no app** (só no hardware Video Assist) |
| LUTs 3D: importar/exportar, usar só no monitor ou gravar no clipe | C |
| Saída HDMI 4K com áudio (3.4) | C |
| Preview 10-bit no controle remoto (3.5) | C |

### 2.4 Áudio
Fonte interna ou microfone externo; 44,1/48 kHz; PCM, IEEE Float, AAC;
mono, estéreo, dual mono, 4 canais. Conf. **P** (tech specs iOS; no Android
o PCM/Float depende do contêiner, que é ponto a confirmar).

### 2.5 Metadados e fluxo de produção
- Slate: reel, cena, take, diretor, tipo de plano, projeto, dados de lente — **C**
- Timecode record-run ou hora do dia; **Tentacle Sync E via Bluetooth** — **C**
- Blackmagic Cloud: sobe primeiro o proxy, depois o original, e conecta ao DaVinci Resolve 18.6+ — **C**
- Sincronização remota de clipes com timecode e metadados (3.0) — **C**

### 2.6 Multicâmera e controle remoto
- Um telefone controla até **9 outros** por Wi-Fi ou cabo: start/stop
  sincronizado, ajustes e monitoramento — **C**
- **API REST** de controle remoto (3.4, só Android) — **C**
- Companion **Wear OS** (3.4) e Apple Watch — **C**
- Controle de câmeras PYXIS (iOS 2.2) — **C** (iOS)

### 2.7 Streaming e interface
- Live direto para YouTube, Vimeo e Twitch (3.0) — **C**
- UI 3.0: toque à esquerda abre presets/slate/configurações, à direita
  3 funções programáveis; 3.5 traz busca nas configurações e atalhos de preset — **C**

### 2.8 Plataforma e suporte
Android 13+, lista fechada de aparelhos (Pixel 6–9, Galaxy S21–S25 e Z Fold,
OnePlus 11/12/16, Xiaomi 13/14, Xperia, Oppo Find X10). Em aparelhos fora da
lista o app instala (sideload), mas costuma falhar. — **C**

---

## 3. Análise crítica

**Pontos fortes**
1. É grátis e faz parte de um ecossistema: o app existe para levar gente ao
   DaVinci Resolve e ao Blackmagic Cloud. Não é um produto pensado para dar lucro sozinho.
2. Ferramentas de cinema de verdade (false color calibrado para pele, ângulo
   de obturador, rack focus com presets, slate e timecode) que apps "pro" de consumo não têm.
3. Fluxo completo: proxy na nuvem, conform no Resolve e multicâmera com timecode.
4. Evolução rápida no Android: a 3.4 passou a versão iOS em alguns pontos (REST, HDMI).

**Pontos fracos e lacunas**
1. **Lista de aparelhos fechada.** Fora dela o app não funciona bem. É a maior
   oportunidade: um app que **detecta capacidades em tempo de execução** e se
   adapta (níveis de hardware do Camera2) atende muito mais aparelhos.
2. **Codecs no Android limitados a H.264/H.265**, sem intra-frame. Todo o
   material tem compressão long-GOP, o que pesa na edição.
3. **Sem waveform/vectorscope** (sem evidência). Para quem trabalha com exposição
   em log, o histograma não basta.
4. **Prende ao ecossistema**: nuvem e conform giram em torno de Blackmagic Cloud
   e Resolve. Não há integração com Frame.io, Premiere, Final Cut ou Drive/S3.
5. **Sem foto profissional** (nenhuma evidência de RAW/DNG). O app é só de vídeo.
6. Bugs históricos de reprodução e de selfie espelhada; suporte de lentes
   limitado a 4K na grande-angular em alguns Galaxy.
7. Os recursos de log dependem do fabricante (O-Log2 só em Oppo/OnePlus). Em
   Pixel e Samsung a imagem "plana" depende do que o OEM expõe.

---

## 4. Segunda passada: o que mudei ao reanalisar

| Primeira ideia | Revisão |
|---|---|
| "Copiar todas as funções" | Várias **dependem do ecossistema e não se replicam**: Blackmagic Cloud, controle PYXIS, Focus/Zoom Demand, protocolo Blackmagic Camera Control, conform no Resolve. Vamos oferecer equivalentes abertos (exportação FCPXML/EDL, S3/Drive/Frame.io, BLE genérico) em vez de imitar |
| Usar CameraX (mais simples) | **Camera2 direto**: CameraX não expõe controle fino de exposição/obturador, perfis 10-bit/HLG por stream nem ajustes por quadro. CameraX fica só como fallback para aparelhos LEGACY |
| Oferecer ProRes "como o iOS" | ProRes no Android **exige licença da Apple** para o encoder, e encoder em software consome bateria e esquenta. MVP em HEVC 10-bit; estudar intra-frame (HEVC all-intra via MediaCodec onde houver suporte) como alternativa sem licença |
| Lista de aparelhos como a Blackmagic | **Perfil de capacidades por aparelho** em tempo de execução, mais uma base de "quirks" por modelo. É o diferencial principal |
| Paridade total no lançamento | MVP enxuto e diferenciado (abaixo). Multicâmera, streaming e HDMI vêm em fases |
| Monitoramento igual | **Ir além**: waveform, vectorscope, RGB parade, mapa de clipping por canal. Na GPU custam pouco |

---

## 5. Plano de construção do ISO-Pro

### 5.1 Arquitetura (Android primeiro, Kotlin)
- **Captura:** Camera2 + `CameraCharacteristics` para montar o perfil do
  aparelho (ISO/exposição, fps, `REQUEST_AVAILABLE_DYNAMIC_RANGE_PROFILES`
  para HLG10/10-bit, câmeras físicas da multi-câmera lógica, OIS/EIS).
- **Pipeline de imagem:** `SurfaceTexture` → OpenGL ES 3 / Vulkan. Os
  shaders fazem LUT 3D (.cube), zebra, false color, peaking, e geram
  histograma, waveform e vectorscope por compute shader com amostragem reduzida.
  A mesma textura alimenta o encoder (LUT gravada ou não).
- **Gravação:** `MediaCodec` (HEVC Main10 / H.264) + `MediaMuxer` (MP4/MOV).
  Um segundo encoder em baixa resolução gera o **proxy** em paralelo. Áudio
  com `AudioRecord` (PCM 48 kHz, multicanal quando houver) → AAC ou PCM.
- **Metadados:** timecode (track `tmcd` em MOV ou metadado), slate como
  sidecar JSON e XMP, e exportação **FCPXML/EDL/ALE** para qualquer editor.
- **Rede:** descoberta por NSD/mDNS, controle e telemetria por WebSocket,
  preview por WebRTC (baixa latência), **API REST** (Ktor embutido) e start/stop
  sincronizado com relógio compartilhado.
- **Saídas:** HDMI/DisplayPort via `Presentation`/`DisplayManager`; streaming
  RTMP/SRT; upload em segundo plano (WorkManager), proxy primeiro, para S3/Drive/Frame.io.
- **Acessórios:** Tentacle Sync (timecode BLE), companion Wear OS, controles
  BLE e USB genéricos.

### 5.2 Fases
| Fase | Escopo | Critério de pronto |
|---|---|---|
| 0 | Fechar a lacuna de evidência: análise do APK com REA (seção 6) | Relatório da fase 2 neste arquivo |
| 1 — MVP | Perfil de capacidades; ISO/obturador (velocidade e ângulo)/WB+tint/foco manual; fps; HEVC 10-bit HLG/709; áudio 48 kHz; histograma, zebra, false color, peaking; LUT só no monitor; galeria básica | Grava 4K30 10-bit estável por 30 min em Pixel 8 e Galaxy S24 |
| 2 — Pro | Waveform/vectorscope; LUT gravada; proxy; slate e timecode; presets de foco/rack; FCPXML/EDL | Clipe abre conformado no Resolve e no Premiere |
| 3 — Conectado | Multicâmera (1 controlador + N), API REST, preview remoto, Wear OS, Tentacle | 4 aparelhos com start/stop sincronizado a ±1 quadro |
| 4 — Saídas | HDMI, streaming RTMP/SRT, upload na nuvem | |
| 5 — Extras | Foto RAW/DNG, all-intra, iOS | |

### 5.3 Riscos
- **Fragmentação do Camera2** (o maior risco): a mitigação é o perfil de
  capacidades, uma matriz de testes em aparelhos reais e telemetria opcional
  de capacidades.
- **Térmico e bateria** com 4K + proxy + scopes: medir desde o MVP; scopes
  com amostragem reduzida e a 15 Hz.
- **Licenças:** ProRes e marcas (não usar "Blackmagic", "ProRes" ou "Log" de
  terceiros como nome de recurso sem licença).
- **Monetização:** concorrer com um app grátis. Diferenciais: compatibilidade
  ampla, scopes completos, fluxo aberto (sem prender ao ecossistema),
  fotografia RAW.

---

## 6. Fase 2 pendente: roteiro de análise binária com REA

Quando houver um APK em `targets/` (fora do git), vou rodar:

1. `inspect-android-package`: manifesto, minSdk/targetSdk, permissões
   (CAMERA, RECORD_AUDIO, BLUETOOTH_*, NEARBY_WIFI_DEVICES, FOREGROUND_SERVICE_CAMERA),
   serviços, receivers e `uses-feature`.
2. `decode-android-resources`: configurações expostas, lista de
   aparelhos/quirks embutida, formatos suportados (strings e arrays, só para inventário).
3. `extract-artifact` + `inspect-binary-layout` nas `.so` de `lib/arm64-v8a`:
   saber se há encoder próprio (ProRes/BRAW) ou se tudo passa por MediaCodec,
   e se há Vulkan ou GLES.
4. `inspect-android-class` / `inspect-android-method` em pontos-chave, para
   confirmar como funcionam (não para copiar): construção de `CaptureRequest`
   (controles manuais), seleção de `DynamicRangeProfiles`, servidor REST e
   rotas, descoberta multicâmera (NSD?), integração Tentacle (BLE GATT), Wear OS (Data Layer).
5. Atualizar as linhas **P** e **?** deste documento com o resultado.

## Fontes
- https://www.blackmagicdesign.com/products/blackmagiccamera e /techspecs
- https://www.cined.com/blackmagic-camera-2-0-for-android-released-remote-control-of-multiple-phones-and-more/
- https://petapixel.com/2024/08/06/blackmagic-camera-app-update-adds-multi-cam-control-and-monitoring/
- https://digitalproduction.com/2025/09/12/blackmagic-camera-3-0-remote-clip-syncing-and-multi-cam-control-arrive-on-smartphones/
- https://www.newsshooter.com/2026/07/15/blackmagic-camera-for-android-3-4-update/
- https://www.redsharknews.com/blackmagic-camera-android-3-4-update
- https://nofilmschool.com/blackmagic-camera-for-android-3-5
- https://en.pronews.com/news/20261008152116329.html
- https://www.videomaker.com/reviews/software/blackmagic-camera-review-todays-best-camera-app-for-professionals/
- https://www.phonearena.com/news/blackmagic-camera-1.2-adds-pixel-9-series-support-and-fixes-bugs_id161830
- https://cdm.link/blackmagic-camera-shoots-video-on-your-phone/
- https://forum.blackmagicdesign.com/viewtopic.php?f=2&t=225944
