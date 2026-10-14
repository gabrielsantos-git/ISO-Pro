# Blackmagic Camera — análise de funcionalidades e plano do ISO-Pro

Status: **fase 1 concluída (fontes públicas)**, **fase 2 concluída para o código Java/Kotlin (REA)**, bibliotecas nativas fora de escopo (seção 6.6).
Data: 2026-10-13 (fase 1), 2026-10-14 (fase 2). App de referência: Blackmagic Camera for Android 3.5
(`com.blackmagicdesign.android.blackmagiccam`) e a versão iOS como comparação.

> Regra de sala limpa: este documento registra *o que* o app faz e *quais APIs
> de plataforma* parece usar. Nada de código, strings, ícones ou layouts copiados.

---

## 1. Método e qualidade da evidência

| Fonte | Situação |
|---|---|
| Notícias e changelogs (CineD, PetaPixel, Newsshooter, NoFilmSchool, PRONEWS, RedShark, GSMArena, PhoneArena) | Lidas via busca. Boa cobertura de 1.0 → 3.5 |
| Site oficial / tech specs da Blackmagic | Só trechos indexados. O ambiente bloqueia o acesso direto |
| Análise binária do APK com REA | **Feita** sobre o `base.apk` 3.5.0.0066 (seção 7). Os splits de ABI com as `.so` não vieram |

### Registro de tentativas de análise binária
| Data | Arquivo | SHA-256 | Resultado REA |
|---|---|---|---|
| 2026-10-13 | `uptodown-com.blackmagicdesign.android.blackmagiccam.apk` (14,8 MB) | `dc885921…b342550` | **Não é o app alvo.** `decode_android_resources`: pacote `com.uptodown` 7.41 (instalador da loja Uptodown), assinado por *Uptodown Technologies SL*. `search_android_classes "blackmagic"`: 0 de 13.961 classes; nenhum APK embutido. Descartado |
| 2026-10-13 | `blackmagic-camera.apk` (19,1 MB) | `188bbdb8…cfd4374`[^1] | **Não é o app alvo.** `inspect_android_package`: pacote `cm.aptoide.pt` 9.22.5.3 (instalador da loja Aptoide), certificado sem organização (`ST=Portugal`). 0 ocorrências de "blackmagic" nos 3 DEX. Descartado |
| 2026-10-13 | `blackmagic-camera.apk` (reenvio, idêntico byte a byte ao anterior) | `188bbdb8…cfd4374` | Analisado por completo a pedido do usuário. É o cliente genérico da Aptoide: componentes `cm.aptoide.pt.install.*` (DownloadService, CheckRootOnBoot, RootInstallNotification…), conta, widget de busca, deep links `aptoide://`, `aptoideinstall://`, `market://`; permissões de instalar e remover pacotes, root, boot, CAMERA para QR. Nenhuma referência ao app alvo no DEX, nos recursos, nos assets, no comentário do zip nem no APK Signing Block (só v2, metadados de dependência e padding). **Não é um instalador amarrado ao Blackmagic Camera. Não gera nenhuma evidência sobre o app alvo** |
| 2026-10-14 | `com.blackmagicdesign.android.blackmagiccam-3.5.0.0066.apk` (32 MB, enviado em `.rar`) | `7cab871f…8306b56`[^2] | **App alvo confirmado.** Pacote `com.blackmagicdesign.android.blackmagiccam` 3.5.0.0066 (código 26101002), minSdk 33, targetSdk 37. Carimbo `com.android.stamp.source=https://play.google.com/store` e certificado v2 `O=Google Inc., OU=Android` (formato de chave do Play App Signing). Protegido por `com.pairip` (licença Play). Só o `base.apk`: exige splits `base__abi`, `base__density` |

Requisitos para o próximo arquivo: pacote `com.blackmagicdesign.android.blackmagiccam`; se vier
do Play (split APKs), trazer `base.apk` e todos os `split_*.apk`. O `.apkm` do APKMirror (`3.5.0.0064`) é o formato esperado.

[^2]: SHA-256 completo `7cab871fae9dc367dddf34ef22f10ccb826b9b45aa6736e74375600cf8306b56`.

[^1]: SHA-256 completo `188bbdb899be2da401ac0471ba4d10693612fa1067f2ea0987cc6e1afcfd4374`.

Cada linha abaixo tem um nível de confiança: **C** = confirmado por fonte oficial
ou várias fontes, **P** = provável (uma fonte, ou só iOS), **?** = não confirmado.

## 2. Inventário de funcionalidades

### 2.1 Captura de vídeo
| Recurso | Android | iOS | Conf. |
|---|---|---|---|
| H.264 / H.265 (HEVC) | ✓ | ✓ | C |
| **APV** (Advanced Professional Video, intra) e **AV1** | ✓ | — | **C (binário)** |
| Apple ProRes 422 HQ/422/LT/Proxy | ✗ (não existe no binário) | ✓ | C |
| ProRes RAW (só em disco externo) | ✗ | ✓ | P |
| Até 8K (depende do sensor: S23 Ultra 8K, Pixel 8 Pro 4K) | ✓ | ✓ | C |
| Rec.709, HLG10, **Blackmagic Log**, **Samsung Log** (`com.samsung.android.logvideo`), Oppo Log, "Log HDR"; Apple Log no iOS | ✓ | ✓ | C (binário) |
| 120/240 fps em Sony Xperia (2.0) | ✓ | — | C |
| Proxy HD gravado junto com o original | ✓ | ✓ | C |
| Gravação contínua com pausa (3.4) | ✓ | ? | C |
| Estabilização (OIS + `CONTROL_VIDEO_STABILIZATION_MODE`) | ✓ | ✓ | C (binário) |
| Time-lapse com intervalo selecionável | ✓ | ? | C (binário) |
| Desqueeze anamórfico | ✓ | ✓ | C (binário) |

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
| Waveform / vectorscope | **Ausente no Android** (nenhuma string, rota REST ou classe; só histograma) — C (binário) |
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
| 0 | ~~Fechar a lacuna de evidência com REA~~ **concluída** (seção 6) | ✓ |
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

## 6. Fase 2: resultados da análise binária (REA)

Alvo: `base.apk` 3.5.0.0066 (SHA-256 `7cab871f…8306b56`). Ferramentas: REA
`decode_android_resources` (apktool 2.12.1), `inspect_android_package`,
`search_android_classes`, `inspect_android_class` e `inspect_android_method`
(jadx 0.7.1); jadx também foi usado em lote, fora do git, para buscar usos de
API. Nada de código foi copiado para este repositório; abaixo estão só nomes de
API, formatos e comportamentos observados.

### 6.1 Arquitetura
- **18.848 classes**, das quais 4.499 são da Blackmagic (`com.blackmagicdesign.android.*`),
  com **pacotes sem ofuscação** (membros sim, via R8). UI em Jetpack Compose + Material 3,
  persistência com Room, Glide e RxJava.
- O lado Java/Kotlin é fino: **não há** `MediaMuxer`, `AudioRecord`, `MediaRecorder`
  nem chamadas GLES/Vulkan. Gravação, áudio, ciência de cor e preview ficam em
  **bibliotecas nativas** (`System.loadLibrary`): `graphics_native`, `color_science`,
  `lut_processor`, `lut_float16_parser`, `lut_compressor`, `bmdaudio`, `nativeplayer`,
  `turbojpeg`, `usb-1.0` (libusb), `gstreamer_android`, `gstreamer_android_remote`,
  `davstream`, `bmddavcloudclient`, `tentacle-lib`, mais as do SDK Insta360
  (`One`, `insbase2`, `arffmpeg`, `asl`, `arypto`).
- **Proteção e distribuição:** `com.pairip` (licença Play: `LicenseActivity`,
  `CHECK_LICENSE`) e `com.android.vending.splits.required=true`. Isso explica por que
  o sideload costuma falhar. **Não há lista de aparelhos no código Java**: o filtro vem
  de `uses-feature` obrigatórios (`camera.capability.manual_post_processing`,
  `opengles.aep`, GLES 3.2, `usb.host`, câmera frontal, microfone), do minSdk 33 e,
  provavelmente, do catálogo de aparelhos do Play Console.

### 6.2 Captura e cor
- **Camera2 direto** (sem CameraX), em `CameraStateController`/`CameraManager`.
  Chaves usadas: `SENSOR_EXPOSURE_TIME`, `SENSOR_SENSITIVITY`, `SENSOR_FRAME_DURATION`,
  `LENS_FOCUS_DISTANCE`, `LENS_APERTURE`, `CONTROL_ZOOM_RATIO`, `SCALER_CROP_REGION`,
  regiões de AF/AE/AWB, locks, compensação de exposição, `CONTROL_AE_TARGET_FPS_RANGE`,
  antibanding, `NOISE_REDUCTION_MODE`, `EDGE_MODE`, `TONEMAP_MODE`,
  `DISTORTION_CORRECTION_MODE`, `LENS_OPTICAL_STABILIZATION_MODE`,
  `CONTROL_VIDEO_STABILIZATION_MODE`, `COLOR_CORRECTION_TRANSFORM/GAINS`.
- **APIs novas do Android 16:** `COLOR_CORRECTION_MODE` com
  `COLOR_CORRECTION_COLOR_TEMPERATURE` e `COLOR_CORRECTION_COLOR_TINT` (WB em Kelvin +
  tint nativo) e `CONTROL_AE_PRIORITY_MODE` (prioridade de ISO ou obturador). Do Android 15:
  `FLASH_STRENGTH_LEVEL` (intensidade da lanterna).
- **Codecs** (`VideoCodecFormat`): **H264, HEVC, AV1, APV**. Sem ProRes no Android.
- **Curvas:** Blackmagic Log, Samsung Log (`com.samsung.android.logvideo`), Oppo Log,
  HLG10, "Log HDR". A lib `color_science` sugere que o Blackmagic Log é gerado pelo app.
- **LUT:** importação `.cube`, LUTs Blackmagic embutidas, exportação, LUT de display
  ou gravada; processamento nativo em float16.
- **Metadados:** biblioteca interna de boxes MP4/MOV (derivada do JCodec) com
  `TimecodeBoxes`, `MetaDataBoxes` e `XMLMetaDataSampleEntry`; grava chaves
  QuickTime como `com.apple.proapps.logNote` (lidas por Final Cut e Resolve). Timecode
  via Tentacle (lib nativa por SWIG) e localização GPS opcional nos clipes.
- **Modos de preview:** normal, intervalo (time-lapse) e pausado.

### 6.3 Controle remoto, rede e API REST
- **Servidor HTTP embutido** com Ktor + Netty, base **`/control/api/v1`**, com
  documentação servida pelo próprio app (`/control/documentation.html` e
  `notification.yaml`). É o mesmo padrão da API REST pública das câmeras Blackmagic.
- **203 endpoints** cobrindo: transporte (gravar, parar, reproduzir, clipes, timeline),
  formato de vídeo e codec, ISO, ganho, obturador (incluindo flicker-free), WB/tint,
  foco/AF/rastreio de rosto, íris, zoom, *jump points* de foco e zoom, filtro ND, OIS,
  **correção de cor ao vivo** (lift, gamma, gain, offset, contraste, cor, contribuição
  de luma), monitoramento (false color, zebra, focus assist, grades, frame guides,
  safe area, LUT de display, clean feed, color bars, program feed), áudio
  (canais, phantom power, pad, low cut, codec), slate (projeto, lente, take com
  autoincremento), timecode, tally, mídia (slots, formatar, sistemas de arquivo),
  Blackmagic Cloud (projetos, upload), livestream (plataformas, status) e sensor de
  movimento (euler, horizonte).
- **Descoberta:** mDNS com `_bmd-cam-control._tcp` e `_http._tcp` (JmDNS + NsdManager).
- **Sinalização multicâmera:** servidor e cliente WebSocket e canal TCP próprios.
  Preview remoto 10-bit e sincronização de mídia (`mediasync`). Controle de
  câmeras Blackmagic de hardware (`remote.control.hwcam`, de onde vêm XLR, pré-gravação e foto).
- **Streaming:** GStreamer nativo com variante **SRT** (`NativeSRTGstreamer`), YouTube,
  Vimeo, Twitch, chave e passphrase, além do *stream router* do Blackmagic Cloud.

### 6.4 Acessórios e periféricos (nada disso aparecia nas fontes públicas)
- **Gimbal Insta360** (SDK Arashivision, string `insta360_gimbal_control`).
- **Tilta Nucleus**: controle de lente sem fio por **BLE GATT** e por **USB MIDI**
  (`MidiManager` em `hardware.tilta`).
- **Blackmagic Focus/Zoom Demand** (`hardware.bmdemand`).
- **Tentacle Sync** (lib nativa).
- **Wear OS** (`WearListenerService`, Data Layer).
- **Microfones USB/Bluetooth** detectados por `AudioDeviceInfo` (`AudioDeviceDetector`).
- **Saída HDMI** com clean feed (via `DisplayManager`).
- **Aviso de temperatura** do aparelho (status térmico do `PowerManager`).

### 6.5 Blackmagic Cloud
Cliente nativo (`bmddavcloudclient`): login OAuth, organizações, projetos, armazenamento,
**chat** e *stream router*; gerenciador de proxies (upload do proxy primeiro).

### 6.6 Não verificado (precisaria dos splits com as `.so`)
Formatos e resoluções exatos por aparelho, como o Blackmagic Log é calculado, o
pipeline de encode (MediaCodec via NDK?) e a implementação do preview. Para isso é preciso o
`split_config.arm64_v8a.apk`, que vem dentro do `.apkm`.

**Decisão (2026-10-14):** não será buscado. O arquivo não passa pelo limite de upload da sessão, e esses detalhes não mudam nenhuma decisão do plano: o ISO-Pro implementa o próprio pipeline e a própria curva log. Se for preciso no futuro, o caminho é `adb pull` do split instalado no celular.

---

## 7. Terceira passada: o que a fase 2 mudou no plano

| Antes (fase 1) | Depois (evidência binária) |
|---|---|
| Sem ProRes; estudar HEVC all-intra | **Adotar APV** como codec "pro" intra: aberto, sem royalties e já no MediaCodec do Android 16+ (é o que a Blackmagic usa). HEVC/AV1 para entrega |
| WB/ISO/obturador via controle manual "cru" do Camera2 | Usar **`COLOR_CORRECTION_COLOR_TEMPERATURE/TINT`** e **`CONTROL_AE_PRIORITY_MODE`** quando existirem (Android 16+), com fallback para `COLOR_CORRECTION_GAINS` + `TRANSFORM` e exposição manual |
| Lista de aparelhos ruim, capacidades em runtime são o diferencial | Confirmado e reforçado: a Blackmagic filtra por `uses-feature` rígidos e minSdk 33. Nosso app deve **degradar com elegância** (sem exigir `manual_post_processing` nem AEP) |
| Log só se o fabricante expuser | Dois níveis: **log do fabricante** quando houver (Samsung e Oppo expõem) e **nossa curva log** aplicada no pipeline, como a Blackmagic faz |
| API REST própria | Seguir o **formato público `/control/api/v1`** da Blackmagic (documentado para as câmeras deles) dá interoperabilidade com ferramentas existentes. É uma decisão de produto e jurídica (seção 7.1) |
| Pipeline em Kotlin + GLES | Hot path (preview, LUT, scopes, encode) em **C++/NDK**, como a Blackmagic. Kotlin só para UI e orquestração |
| Waveform/vectorscope seriam "ir além" | Confirmado: **o app Android não tem**. Continua sendo diferencial |
| Acessórios: Tentacle e BLE genérico | Prioridade para os mais usados: **Tilta Nucleus (USB MIDI/BLE)**, gimbals (Insta360/DJI via SDK oficial), Tentacle, Wear OS |
| Streaming RTMP/SRT | **SRT** primeiro (GStreamer ou libsrt), RTMP depois |

### 7.1 Limites legais e de sala limpa
- Usar a evidência só como especificação de comportamento. Nenhum código, string,
  LUT, curva ou recurso gráfico da Blackmagic entra no ISO-Pro.
- "Blackmagic Log", "Blackmagic Cloud" e o protocolo de nuvem são proprietários:
  não replicar. Compatibilidade com a API REST pública é interoperabilidade, mas
  precisa de revisão jurídica antes de virar recurso.
- Bibliotecas abertas que eles usam e que podemos usar com licença compatível:
  Ktor (Apache-2.0), Netty (Apache-2.0), JmDNS (Apache-2.0), JCodec (BSD-2),
  GStreamer (LGPL, cuidado com linkagem), libusb (LGPL), libjpeg-turbo (BSD).

### 7.2 Fases revisadas
| Fase | Mudanças |
|---|---|
| 1 — MVP | Pipeline nativo (NDK) desde o início; HEVC 10-bit + **APV** onde houver suporte; WB em Kelvin/tint e prioridade de AE pelas APIs do Android 16 com fallback |
| 2 — Pro | + waveform/vectorscope (diferencial), curva log própria, LUT `.cube`, timecode `tmcd` + metadados QuickTime |
| 3 — Conectado | API REST (`/control/api/v1`-compatível, se aprovado), mDNS, WebSocket, Tilta Nucleus, Wear OS |
| 4 — Saídas | HDMI clean feed, **SRT**, RTMP |

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
