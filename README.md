# SystemMonitor

Monitoramento de sistema em tempo real para macOS (Apple Silicon M1+/M2+).

## Recursos

- **CPU %** - Uso de processador
- **RAM %** - Uso de memória
- **GPU %** - Uso de GPU (best effort)
- **Thermal State** - Estado térmico do sistema
- **Menu Bar** - Exibição na barra de menus
- **Dashboard** - Janela com gráficos detalhados
- **Auto-login** - Iniciar com o sistema

## Requisitos

- macOS 13.0 (Ventura) ou superior
- Apple Silicon (M1, M2, M3, M4, M5)
- Xcode 15.3+

## Instalação

### Pré-requisitos

1. **Instalar Xcode** (se não tiver):
   ```bash
   xcode-select --install
   ```

2. **Instalar Command Line Tools**:
   ```bash
   xcode-select --install
   ```

### Compilação

1. Clone ou faça download deste projeto:
   ```bash
   cd SystemMonitor
   ```

2. Compile o projeto:
   ```bash
   swift build -c release
   ```

3. O executável será criado em:
   ```
   .build/release/SystemMonitor
   ```

### Instalação do App

1. Copie o executável para Applications:
   ```bash
   cp .build/release/SystemMonitor /Applications/SystemMonitor
   ```

2. Dê permissão de execução:
   ```bash
   chmod +x /Applications/SystemMonitor
   ```

3. (Opcional) Adicione ao Login Items:
   - Abra **System Preferences** > **Users & Groups** > **Login Items**
   - Clique em **+** e adicione SystemMonitor

### Executando

Execute diretamente:
```bash
/Applications/SystemMonitor
```

Ou pelo Xcode:
```bash
open SystemMonitor.xcodeproj
```
 ثم اضغط **Run** (⌘R)

## Uso

### Menu Bar

O app aparece na barra de menus mostrando:
```
CPU: 12% | RAM: 47% | 🟢
```

Clique para abrir o Dashboard.

### Dashboard

- **CPU** - Gráfico de barras com uso
- **RAM** - Gráfico com uso de memória
- **GPU** - Uso de GPU (estimado)
- **Thermal State** - Estado térmico com indicadores de cor

### Configurações

- **Intervalo de atualização** - 1s, 2s, 5s, 10s, 30s (padrão: 5s)
- **Iniciar automaticamente** - Toggle para auto-login

## Solução de Problemas

### "App não pode ser aberto porque é de desenvolvedor desconhecido"

1. Clique direito no app
2. Escolha "Open"
3. Clique "Open" novamente na dialog

### Thermal State não mostra temperaturas

O Thermal State usa a API oficial da Apple (`ProcessInfo.thermalState`) que retorna níveis, não temperaturas precisas. Isso é por design da Apple.

### GPU mostra 0% ou não disponível

A medição de GPU em Apple Silicon usa APIs não oficiais. Alguns modelos podem não retornar valores precisos.

## Arquitetura

```
SystemMonitor/
├── Sources/SystemMonitor/
│   ├── App/SystemMonitorApp.swift      # App principal
│   ├── Models/SystemMetrics.swift      # Modelos de dados
│   ├── Services/SystemMonitorService.swift  # Serviço de monitoramento
│   ├── Views/
│   │   ├── DashboardView.swift         # Janela principal
│   │   └── Components/
│   │       ├── CPUChartView.swift
│   │       ├── RAMChartView.swift
│   │       ├── GPUChartView.swift
│   │       └── ThermalStateView.swift
│   └── Utilities/Settings.swift     # Configurações
└── Resources/Assets.xcassets
```

## Tecnologias

- **SwiftUI** - Interface nativa Apple
- **Swift Charts** - Gráficos (macOS 13+)
- **IOKit** - Acesso a sensores
- **Mach APIs** - CPU/RAM stats
- **ServiceManagement** - Auto-login

## Licença

MIT License

## Autor

Feito com SwiftUI para macOS