import { SAMPLE_RECORD_SEEDS, type SecurityLabelLevel, type VaultItem } from '../model/VaultModels';
import { type StorageSnapshot, type VaultHealthSummary, VaultPageState } from '../state/VaultPageState';
import {
  canRaiseSecurityLabel,
  createInitialVaultItems,
  demoRecommendedLabel,
  formatBytes,
  labelActionHint,
  labelActionText,
  labelRank,
  normalizeSecurityLabel,
  shortHash,
  shortPath,
  statusColor,
  summarizeVaultHealth
} from '../utils/VaultUiUtils';
import { fileIo, fileUri, hash, securityLabel, statfs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const ROUTE_HOME: string = 'vault_home', ROUTE_DETAIL: string = 'vault_item_detail', ROUTE_STORAGE: string = 'storage_diagnostics';
const METADATA_FILE_NAME: string = 'secure-vault-baseline.txt';
const LOG_DOMAIN: number = 0x0000;
const LOG_TAG: string = 'SecureVault';

function logWarning(message: string, error: Error): void {
  hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s: %{public}s', message, error.message);
}

@Builder
function header(title: string, subtitle: string) {
  Column({ space: 3 }) {
    Text(title)
      .fontSize(13)
      .fontColor('#F5F7FA')
      .fontWeight(FontWeight.Medium)
    Text(subtitle)
      .fontSize(9)
      .fontColor('#99A3B5')
      .maxLines(2)
  }
  .width('100%')
  .alignItems(HorizontalAlign.Center)
}

@Component
struct VaultHomePage {
  @ObjectLink vaultState: VaultPageState;
  openItemAction: (itemId: string) => void = () => {
  };
  openStorageAction: () => void = () => {
  };

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 7 }) {
          header('Vault', 'Open a record to verify trust.')
          Column({ space: 3 }) {
            Text('Health').fontSize(10).fontColor('#F5F7FA').fontWeight(FontWeight.Medium)
            Text(`${this.summarizeVaultHealth().verified}/${this.summarizeVaultHealth()
              .total} verified · ${this.summarizeVaultHealth().unknown} pending`)
              .fontSize(8).fontColor('#AFC8E8')
            if (this.summarizeVaultHealth().mismatch > 0 || this.summarizeVaultHealth().error > 0) {
              Text(`${this.summarizeVaultHealth().mismatch} mismatch · ${this.summarizeVaultHealth().error} error`)
                .fontSize(8)
                .fontColor('#FFB0A0')
            } else {
              Text('No trust failures detected.')
                .fontSize(8)
                .fontColor('#7CE5A7')
            }
          }
          .width('100%')
          .padding(8)
          .backgroundColor('#1B2A3D')
          .borderRadius(14)
          .alignItems(HorizontalAlign.Center)

          ForEach(this.vaultState.items, (item: VaultItem) => {
            Column({ space: 3 }) {
              Text(item.title).fontSize(10).fontColor('#F5F7FA').fontWeight(FontWeight.Medium).maxLines(1)
              if (item.lastVerificationStatus === 'verified') {
                Text(item.summaryLine).fontSize(8).fontColor('#9AA5B8').maxLines(1)
              } else if (item.lastVerificationStatus === 'mismatch') {
                Text('Summary locked: file changed.').fontSize(8).fontColor('#FFB0A0').maxLines(1)
              } else if (item.lastVerificationStatus === 'error') {
                Text('Summary locked: read failed.').fontSize(8).fontColor('#FFB0A0').maxLines(1)
              } else {
                Text('Summary locked until verified.').fontSize(8).fontColor('#E8B17A').maxLines(1)
              }
              Text(`Label ${item.currentSecurityLabel} · ${item.lastVerificationStatus}`)
                .fontSize(8).fontColor(statusColor(item.lastVerificationStatus)).maxLines(1)
              if (item.lastVerificationStatus === 'mismatch') {
                Text('Changed after setup.')
                  .fontSize(8)
                  .fontColor('#FFB0A0')
                  .maxLines(1)
              }
            }
            .width('100%')
            .padding(8)
            .backgroundColor('#182233')
            .borderRadius(14)
            .onClick(() => this.openItemAction(item.id))
          }, (item: VaultItem) => `${item.id}-${item.lastVerificationStatus}-${item.currentSecurityLabel}-${item.expectedSha256}`)

          Button('Storage')
            .width('100%')
            .height(26)
            .backgroundColor('#294463')
            .fontSize(9)
            .fontColor('#EAF2FF')
            .onClick(() => this.openStorageAction())
        }
        .padding({
          left: 28,
          right: 28,
          top: 20,
          bottom: 24
        })
        .width('100%')
      }
      .scrollBar(BarState.Off)
    }
    .hideTitleBar(true)
    .backgroundColor('#10161F')
  }

  private summarizeVaultHealth(): VaultHealthSummary {
    return summarizeVaultHealth(this.vaultState.items);
  }
}

@Component
struct VaultDetailPage {
  @ObjectLink vaultState: VaultPageState;
  @Prop canOperateOnFile: boolean = false;

  verifyAction: () => void = () => {
  };

  raiseLabelAction: () => void = () => {
  };

  tamperAction: () => void = () => {
  };

  recreateAction: () => void = () => {
  };

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 7 }) {
          header('Record', 'Check trust, then read.')
          if (this.selectedItem()) {
            Text(this.selectedItem()!.title).fontSize(11).fontColor('#F5F7FA').fontWeight(FontWeight.Medium).maxLines(1)
            Column({ space: 3 }) {
              Text('Trust').fontSize(10).fontColor('#F5F7FA')
              Text(`${this.selectedItem()!.lastVerificationStatus}`).fontSize(12)
                .fontColor(statusColor(this.selectedItem()!.lastVerificationStatus))
                .fontWeight(FontWeight.Medium)
              if (this.selectedItem()!.lastVerificationStatus === 'mismatch') {
                Text('Changed on disk. Restore clean file.')
                  .fontSize(8).fontColor('#FFB0A0').maxLines(2)
              } else if (this.selectedItem()!.lastVerificationStatus === 'error') {
                Text('Could not read this file.')
                  .fontSize(8).fontColor('#FFB0A0').maxLines(2)
              }
            }.width('100%').padding(8).backgroundColor('#182233').borderRadius(14)

            Column({ space: 2 }) {
              Text('File').fontSize(10).fontColor('#F5F7FA')
              Text(`Path: ${shortPath(this.selectedItem()!.filePath)}`).fontSize(8).fontColor('#93A0B6').maxLines(1)
              Text(`Hash: ${shortHash(this.selectedItem()!.expectedSha256)}`)
                .fontSize(8)
                .fontColor('#93A0B6')
                .maxLines(1)
            }.width('100%').padding(8).backgroundColor('#182233').borderRadius(14)

            Column({ space: 3 }) {
              Text('Security label').fontSize(10).fontColor('#F5F7FA')
              Text(`${this.selectedItem()!.currentSecurityLabel} → ${this.selectedItem()!.recommendedSecurityLabel}`)
                .fontSize(9)
                .fontColor(canRaiseSecurityLabel(this.selectedItem()) ? '#E8B17A' : '#7CE5A7')
                .maxLines(1)
              if (canRaiseSecurityLabel(this.selectedItem())) {
                Text(labelActionHint(this.selectedItem())).fontSize(8).fontColor('#9AA5B8').maxLines(2)
              }
            }.width('100%').padding(8).backgroundColor('#182233').borderRadius(14)

            Column({ space: 6 }) {
              Button('Verify Now')
                .width('100%')
                .height(24)
                .backgroundColor(this.canOperateOnFile ? '#2E5B8A' : '#3E4452')
                .fontSize(9)
                .fontColor('#F4F8FF')
                .enabled(this.canOperateOnFile)
                .onClick(() => this.verifyAction())
              Button(labelActionText(this.selectedItem()))
                .width('100%')
                .height(24)
                .backgroundColor(this.canOperateOnFile && canRaiseSecurityLabel(this.selectedItem()) ? '#3E6F50' :
                  '#3E4452')
                .fontSize(9)
                .fontColor('#F4F8FF')
                .enabled(this.canOperateOnFile && canRaiseSecurityLabel(this.selectedItem()))
                .onClick(() => this.raiseLabelAction())
              Button('Break File')
                .width('100%')
                .height(24)
                .backgroundColor(this.canOperateOnFile ? '#7A4A4A' : '#3E4452')
                .fontSize(9)
                .fontColor('#F4F8FF')
                .enabled(this.canOperateOnFile)
                .onClick(() => this.tamperAction())
              Button('Restore Clean File')
                .width('100%')
                .height(24)
                .backgroundColor(this.canOperateOnFile ? '#4F6A3C' : '#3E4452')
                .fontSize(9)
                .fontColor('#F4F8FF')
                .enabled(this.canOperateOnFile)
                .onClick(() => this.recreateAction())
            }
            .width('100%')

            if (this.selectedItem()!.lastVerificationStatus === 'verified') {
              Text('Trusted preview').fontSize(9).fontColor('#D8E6FF')
              Text(this.vaultState.detailPreview || 'No preview available.')
                .fontSize(8)
                .fontColor('#D8E6FF')
                .maxLines(4)
            } else {
              Text('Preview locked until verified.')
                .fontSize(8)
                .fontColor('#E8B17A')
                .maxLines(2)
            }
            Text(this.vaultState.detailMessage).fontSize(8).fontColor('#D7E5FF').maxLines(3)
          } else {
            Text('No item selected.').fontSize(10).fontColor('#D9E3F0')
          }
        }
        .padding({
          left: 28,
          right: 28,
          top: 20,
          bottom: 24
        })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .scrollBar(BarState.Off)
    }
    .hideTitleBar(true)
    .backgroundColor('#10161F')
  }

  private selectedItem(): VaultItem | undefined {
    return this.vaultState.items.find((current: VaultItem) => current.id === this.vaultState.selectedItemId);
  }
}

@Component
struct StorageDiagnosticsPage {
  @ObjectLink vaultState: VaultPageState;
  loadAction: () => void = () => {
  };

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 7 }) {
          header('Storage', 'Watch filesystem space.')
          Button('Refresh Space')
            .width('100%')
            .height(26)
            .backgroundColor('#294463')
            .fontSize(9)
            .fontColor('#EAF2FF')
            .onClick(() => this.loadAction())
          Column({ space: 3 }) {
            Text('Filesystem').fontSize(10).fontColor('#F5F7FA')
            Text(`Free: ${formatBytes(this.vaultState.storageSnapshot.fileSystemFreeSize)}`)
              .fontSize(8)
              .fontColor('#A5B0C3')
            Text(`Total: ${formatBytes(this.vaultState.storageSnapshot.fileSystemTotalSize)}`)
              .fontSize(8)
              .fontColor('#A5B0C3')
            if (this.vaultState.storageSnapshot.fileSystemFreeError) {
              Text(`Free error: ${this.vaultState.storageSnapshot.fileSystemFreeError}`)
                .fontSize(8)
                .fontColor('#E8B17A')
                .maxLines(1)
            }
            if (this.vaultState.storageSnapshot.fileSystemTotalError) {
              Text(`Total error: ${this.vaultState.storageSnapshot.fileSystemTotalError}`)
                .fontSize(8)
                .fontColor('#E8B17A')
                .maxLines(1)
            }
            Text('Measured with statfs on the app sandbox path.')
              .fontSize(8)
              .fontColor('#93A0B6')
              .maxLines(2)
          }
          .width('100%').padding(8).backgroundColor('#182233').borderRadius(14)

          Text(this.vaultState.storageMessage).fontSize(8).fontColor('#D7E5FF').maxLines(3)
        }
        .padding({
          left: 28,
          right: 28,
          top: 20,
          bottom: 24
        })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .scrollBar(BarState.Off)
    }
    .hideTitleBar(true)
    .backgroundColor('#10161F')
  }
}

@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();
  @State private vaultState: VaultPageState = new VaultPageState(createInitialVaultItems());

  build() {
    Navigation(this.pathStack) {
      Scroll() {
        Column({ space: 8 }) {
          header('Secure Vault', 'Local file trust demo.')
          Column({ space: 3 }) {
            Text(this.vaultState.setupCompleted ? 'Vault ready' : 'First run')
              .fontSize(11)
              .fontColor(this.vaultState.setupCompleted ? '#7CE5A7' : '#E8B17A')
              .fontWeight(FontWeight.Medium)
            Text(this.vaultState.setupCompleted ? 'Sandbox files restored.' : 'Create sample files once.')
              .fontSize(8)
              .fontColor('#A5B0C3')
              .maxLines(3)
          }
          .width('100%')
          .padding(8)
          .backgroundColor('#182233')
          .borderRadius(14)
          .alignItems(HorizontalAlign.Center)

          Button(this.vaultState.setupCompleted ? 'Refresh Sandbox' : 'Setup Sandbox')
            .width('100%')
            .height(26)
            .backgroundColor('#3E6F50')
            .fontSize(9)
            .fontColor('#F4F8FF')
            .onClick(() => this.seedVault())
          Button('Open Vault')
            .width('100%')
            .height(26)
            .backgroundColor(this.vaultState.setupCompleted ? '#2E5B8A' : '#3E4452')
            .fontSize(9)
            .fontColor('#F4F8FF')
            .enabled(this.vaultState.setupCompleted)
            .onClick(() => this.pathStack.pushPath({ name: ROUTE_HOME }))
          Text('Open a record to check trust.')
            .fontSize(8)
            .fontColor('#A5B0C3')
            .maxLines(2)
          Text(this.vaultState.detailMessage)
            .fontSize(8)
            .fontColor('#D7E5FF')
            .maxLines(3)
        }
        .padding({
          left: 28,
          right: 28,
          top: 26,
          bottom: 24
        })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .scrollBar(BarState.Off)
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .backgroundColor('#10161F')
    .navDestination(this.pageMap)
    .onAppear(() => this.restoreVaultIfPresent())
    .width('100%')
    .height('100%')
  }

  private copyItem(source: VaultItem): VaultItem {
    return {
      id: source.id,
      category: source.category,
      title: source.title,
      fileName: source.fileName,
      filePath: source.filePath,
      fileUri: source.fileUri,
      expectedSha256: source.expectedSha256,
      currentSecurityLabel: source.currentSecurityLabel,
      recommendedSecurityLabel: source.recommendedSecurityLabel,
      lastVerificationStatus: source.lastVerificationStatus,
      lastVerificationTime: source.lastVerificationTime,
      summaryLine: source.summaryLine
    };
  }

  private getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private metadataPath(): string {
    return `${this.getAbilityContext().filesDir}/${METADATA_FILE_NAME}`;
  }

  private writeText(path: string, content: string): void {
    let writer: fileIo.File | undefined = undefined;
    try {
      writer = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(writer.fd, content);
    } catch (error) {
      logWarning('Metadata write failed', error as Error);
      throw new Error(`Metadata write failed: ${(error as Error).message}`);
    } finally {
      if (writer) {
        try {
          fileIo.closeSync(writer);
        } catch (error) {
          logWarning('Metadata writer close failed', error as Error);
        }
      }
    }
  }

  private readText(path: string): string {
    let reader: fileIo.File | undefined = undefined;
    try {
      reader = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(4096);
      const readLen: number = fileIo.readSync(reader.fd, buffer);
      if (readLen <= 0) {
        return '';
      }
      return String.fromCharCode(...new Uint8Array(buffer.slice(0, readLen)));
    } catch (error) {
      logWarning('Metadata read failed', error as Error);
      throw new Error(`Metadata read failed: ${(error as Error).message}`);
    } finally {
      if (reader) {
        try {
          fileIo.closeSync(reader);
        } catch (error) {
          logWarning('Metadata reader close failed', error as Error);
        }
      }
    }
  }

  private baselineHashFromMetadata(metadata: string, itemId: string): string {
    const lines: string[] = metadata.split('\n');
    for (let index = 0; index < lines.length; index++) {
      const parts: string[] = lines[index].split('|');
      if (parts.length >= 2 && parts[0] === itemId) {
        return parts[1];
      }
    }
    return '';
  }

  private recommendedLabelFromMetadata(metadata: string, itemId: string,
    fallback: SecurityLabelLevel): SecurityLabelLevel {
    const lines: string[] = metadata.split('\n');
    for (let index = 0; index < lines.length; index++) {
      const parts: string[] = lines[index].split('|');
      if (parts.length >= 4 && parts[0] === itemId) {
        return normalizeSecurityLabel(parts[3], fallback);
      }
    }
    return fallback;
  }

  private saveMetadata(items: VaultItem[]): void {
    const lines: string[] =
      items.map((item: VaultItem) => `${item.id}|${item.expectedSha256}|${item.currentSecurityLabel}|${item.recommendedSecurityLabel}`);
    this.writeText(this.metadataPath(), lines.join('\n'));
  }

  private restoreVaultIfPresent(): void {
    if (this.vaultState.setupCompleted) {
      return;
    }
    try {
      const basePath: string = this.getAbilityContext().filesDir;
      let metadata: string = '';
      try {
        metadata = this.readText(this.metadataPath());
      } catch (error) {
        logWarning('Metadata restore read skipped', error as Error);
      }
      const restored: VaultItem[] = this.vaultState.items.map((item: VaultItem) => {
        const seed = SAMPLE_RECORD_SEEDS.find((current) => current.id === item.id)!;
        const path: string = `${basePath}/${seed.fileName}`;
        let reader: fileIo.File | undefined = undefined;
        try {
          reader = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
        } catch (error) {
          logWarning('Restore file probe failed', error as Error);
          throw new Error((error as Error).message);
        } finally {
          if (reader) {
            try {
              fileIo.closeSync(reader);
            } catch (error) {
              logWarning('Restore file probe close failed', error as Error);
            }
          }
        }
        const nextItem = this.copyItem(item);
        nextItem.filePath = path;
        nextItem.fileUri = fileUri.getUriFromPath(path);
        nextItem.expectedSha256 = this.baselineHashFromMetadata(metadata, item.id) || this.hashByStream(path);
        nextItem.lastVerificationStatus = 'unknown';
        try {
          nextItem.currentSecurityLabel = securityLabel.getSecurityLabelSync(path) as SecurityLabelLevel;
        } catch (error) {
          logWarning('Security label restore fallback', error as Error);
          nextItem.currentSecurityLabel = item.recommendedSecurityLabel;
        }
        const demoTarget: SecurityLabelLevel =
          demoRecommendedLabel(nextItem.currentSecurityLabel, seed.recommendedSecurityLabel);
        nextItem.recommendedSecurityLabel = this.recommendedLabelFromMetadata(metadata, item.id, demoTarget);
        if (labelRank(nextItem.recommendedSecurityLabel) < labelRank(nextItem.currentSecurityLabel)) {
          nextItem.recommendedSecurityLabel = nextItem.currentSecurityLabel;
        }
        return nextItem;
      });
      this.vaultState.items = restored;
      this.vaultState.setupCompleted = true;
      this.vaultState.detailMessage = 'Existing sandbox restored. Open Vault is ready.';
      if (!metadata) {
        this.saveMetadata(restored);
      }
    } catch (error) {
      logWarning('Vault restore skipped', error as Error);
      this.vaultState.setupCompleted = false;
      this.vaultState.detailMessage = 'Setup not started.';
    }
  }

  private hashByStream(path: string): string {
    let opened: fileIo.File | undefined = undefined;
    let hs: hash.HashStream;
    try {
      hs = hash.createHash('sha256');
      opened = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const blockSize: number = 64;
      const chunk: ArrayBuffer = new ArrayBuffer(blockSize);
      let readLen: number = fileIo.readSync(opened.fd, chunk);
      while (readLen > 0) {
        hs.update(chunk.slice(0, readLen));
        readLen = fileIo.readSync(opened.fd, chunk);
      }
      return hs.digest();
    } catch (error) {
      logWarning('Hash stream failed', error as Error);
      throw new Error(`Hash stream failed: ${(error as Error).message}`);
    } finally {
      if (opened) {
        try {
          fileIo.closeSync(opened);
        } catch (error) {
          logWarning('Hash stream close failed', error as Error);
        }
      }
    }
  }

  private seedVault(): void {
    try {
      const basePath: string = this.getAbilityContext().filesDir;
      const seededItems: VaultItem[] = this.vaultState.items.map((item: VaultItem) => {
        const seed = SAMPLE_RECORD_SEEDS.find((current) => current.id === item.id)!;
        const path: string = `${basePath}/${seed.fileName}`;
        const writer =
          fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        try {
          fileIo.writeSync(writer.fd, seed.templateContent);
        } catch (error) {
          logWarning('Seed write failed', error as Error);
          throw new Error((error as Error).message);
        } finally {
          try {
            fileIo.closeSync(writer);
          } catch (error) {
            logWarning('Seed writer close failed', error as Error);
          }
        }
        const uri: string = fileUri.getUriFromPath(path);
        const expected: string = this.hashByStream(path);
        let currentLabel: SecurityLabelLevel = 's3';
        try {
          currentLabel = securityLabel.getSecurityLabelSync(path) as SecurityLabelLevel;
        } catch (error) {
          logWarning('Label read fallback', error as Error);
          this.vaultState.detailMessage = `Label read fallback: ${(error as Error).message}`;
        }
        const nextItem = this.copyItem(item);
        nextItem.filePath = path;
        nextItem.fileUri = uri;
        nextItem.expectedSha256 = expected;
        nextItem.currentSecurityLabel = currentLabel;
        nextItem.recommendedSecurityLabel = demoRecommendedLabel(currentLabel, seed.recommendedSecurityLabel);
        nextItem.lastVerificationStatus = 'unknown';
        return nextItem;
      });
      this.vaultState.items = seededItems;
      this.saveMetadata(seededItems);
      this.vaultState.detailMessage = 'Vault is ready. Open Vault to continue.';
      this.vaultState.setupCompleted = true;
    } catch (error) {
      this.vaultState.detailMessage = `Setup failed: ${(error as Error).message}`;
    }
  }

  private readPreview(path: string): string {
    let opened: fileIo.File | undefined = undefined;
    try {
      opened = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const buf = new ArrayBuffer(256);
        const readLen = fileIo.readSync(opened.fd, buf);
        if (readLen <= 0) {
          return '';
        }
        return String.fromCharCode(...new Uint8Array(buf.slice(0, readLen)));
      } catch (error) {
        logWarning('Preview read operation failed', error as Error);
        throw new Error((error as Error).message);
      } finally {
        if (opened) {
          try {
            fileIo.closeSync(opened);
          } catch (error) {
            logWarning('Preview reader close failed', error as Error);
          }
        }
      }
    } catch (error) {
      logWarning('Preview read failed', error as Error);
      return '';
    }
  }

  private raiseLabel(itemId: string): void {
    const index = this.vaultState.items.findIndex((item) => item.id === itemId);
    if (index < 0) {
      return;
    }
    const item = this.vaultState.items[index];
    if (!item.filePath) {
      this.vaultState.detailMessage = 'Label action unavailable: run setup first.';
      return;
    }
    if (!canRaiseSecurityLabel(item)) {
      if (labelRank(item.currentSecurityLabel) === labelRank(item.recommendedSecurityLabel)) {
        this.vaultState.detailMessage =
          `Label already OK at ${item.currentSecurityLabel}. Nothing changes because the target is the same level.`;
      } else {
        this.vaultState.detailMessage =
          `Cannot lower ${item.currentSecurityLabel} to ${item.recommendedSecurityLabel}. securityLabel only moves low to high.`;
      }
      return;
    }
    const targetLabel: SecurityLabelLevel = item.recommendedSecurityLabel;
    this.vaultState.detailMessage = `Raising label ${item.currentSecurityLabel} → ${targetLabel}...`;
    try {
      securityLabel.setSecurityLabel(item.filePath, targetLabel).then(() => {
        const nextLabel = securityLabel.getSecurityLabelSync(item.filePath) as SecurityLabelLevel;
        const nextItem = this.copyItem(item);
        nextItem.currentSecurityLabel = nextLabel;
        this.vaultState.items[index] = nextItem;
        this.vaultState.items = this.vaultState.items.slice();
        this.saveMetadata(this.vaultState.items);
        if (nextLabel === targetLabel) {
          this.vaultState.detailMessage = `Label raised to ${nextLabel}. This button is now done for this record.`;
        } else {
          this.vaultState.detailMessage = `Label API returned ${nextLabel}; target was ${targetLabel}.`;
        }
      }).catch((error: Error) => {
        logWarning('Label raise promise failed', error);
        this.vaultState.detailMessage = `Label raise failed explicitly: ${error.message}`;
      });
    } catch (error) {
      logWarning('Label raise failed', error as Error);
      this.vaultState.detailMessage = `Label raise failed explicitly: ${(error as Error).message}`;
    }
  }

  private rewriteFromSeed(itemId: string): void {
    const index = this.vaultState.items.findIndex((item) => item.id === itemId);
    if (index < 0) {
      return;
    }
    const item = this.vaultState.items[index];
    const seed = SAMPLE_RECORD_SEEDS.find((current) => current.id === item.id);
    if (!seed || item.filePath.length === 0) {
      return;
    }
    try {
      const writer =
        fileIo.openSync(item.filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(writer.fd, seed.templateContent);
      } catch (error) {
        logWarning('Restore write failed', error as Error);
        throw new Error((error as Error).message);
      } finally {
        try {
          fileIo.closeSync(writer);
        } catch (error) {
          logWarning('Restore writer close failed', error as Error);
        }
      }
    } catch (error) {
      logWarning('Restore failed', error as Error);
      this.vaultState.detailMessage = `Restore failed: ${(error as Error).message}`;
      return;
    }
    const nextItem = this.copyItem(item);
    nextItem.expectedSha256 = this.hashByStream(item.filePath);
    nextItem.lastVerificationStatus = 'unknown';
    nextItem.lastVerificationTime = undefined;
    this.vaultState.items[index] = nextItem;
    this.vaultState.items = this.vaultState.items.slice();
    this.saveMetadata(this.vaultState.items);
    this.vaultState.detailPreview = '';
    this.vaultState.detailMessage = 'Clean file restored. Verify again to restore trust.';
  }

  private tamperItem(itemId: string): void {
    const index = this.vaultState.items.findIndex((item) => item.id === itemId);
    if (index < 0) {
      return;
    }
    const item = this.vaultState.items[index];
    if (item.filePath.length === 0) {
      return;
    }
    const tamperLine: string = `\nTAMPER_NOTE=${new Date().getTime()}`;
    try {
      const writer = fileIo.openSync(item.filePath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.APPEND);
      try {
        fileIo.writeSync(writer.fd, tamperLine);
      } catch (error) {
        logWarning('Break write failed', error as Error);
        throw new Error((error as Error).message);
      } finally {
        try {
          fileIo.closeSync(writer);
        } catch (error) {
          logWarning('Break writer close failed', error as Error);
        }
      }
    } catch (error) {
      logWarning('Break File failed', error as Error);
      this.vaultState.detailMessage = `Break File failed: ${(error as Error).message}`;
      return;
    }
    const nextItem = this.copyItem(item);
    try {
      nextItem.lastVerificationStatus =
        this.hashByStream(item.filePath) === item.expectedSha256 ? 'verified' : 'mismatch';
      nextItem.lastVerificationTime = new Date().toLocaleString();
    } catch (error) {
      logWarning('Break File verification failed', error as Error);
      nextItem.lastVerificationStatus = 'error';
      nextItem.lastVerificationTime = new Date().toLocaleString();
    }
    this.vaultState.items[index] = nextItem;
    this.vaultState.items = this.vaultState.items.slice();
    this.saveMetadata(this.vaultState.items);
    this.vaultState.detailPreview = '';
    this.vaultState.detailMessage = 'File broken. Health now shows the mismatch.';
  }

  private loadStorageDiagnostics(): void {
    let snap: StorageSnapshot = {};
    const filesDir: string = this.getAbilityContext().filesDir;
    try {
      snap.fileSystemFreeSize = statfs.getFreeSizeSync(filesDir);
    } catch (error) {
      snap.fileSystemFreeError = (error as Error).message;
    }
    try {
      snap.fileSystemTotalSize = statfs.getTotalSizeSync(filesDir);
    } catch (error) {
      snap.fileSystemTotalError = (error as Error).message;
    }
    this.vaultState.storageSnapshot = snap;
    this.vaultState.storageMessage =
      snap.fileSystemFreeError || snap.fileSystemTotalError ? 'Space refresh partially failed; see metric errors.' :
        'Space refreshed.';
  }

  private verifyAndRefresh(itemId: string): void {
    const index = this.vaultState.items.findIndex((item) => item.id === itemId);
    if (index < 0) {
      return;
    }
    const item = this.vaultState.items[index];
    try {
      if (!item.fileUri || !item.fileUri.startsWith('file://')) {
        throw new Error('Invalid URI teaching checkpoint: URI is missing or malformed. Re-run setup to restore file:// URI.');
      }
      if (!item.filePath) {
        throw new Error('Invalid path teaching checkpoint: expected file path is missing. Re-run setup.');
      }
      const resolvedPath: string = new fileUri.FileUri(item.fileUri).path;
      this.vaultState.detailResolvedPath = resolvedPath || 'unresolved';
      if (!resolvedPath) {
        throw new Error('Invalid URI teaching checkpoint: reverse resolution produced an empty path.');
      }
      if (resolvedPath !== item.filePath) {
        throw new Error('Invalid URI/path teaching checkpoint: resolved path does not match expected sandbox path.');
      }
      const currentHash = this.hashByStream(item.filePath);
      const nextStatus = currentHash === item.expectedSha256 ? 'verified' : 'mismatch';
      const nextItem = this.copyItem(item);
      nextItem.lastVerificationStatus = nextStatus;
      nextItem.lastVerificationTime = new Date().toLocaleString();
      nextItem.currentSecurityLabel = securityLabel.getSecurityLabelSync(item.filePath) as SecurityLabelLevel;
      this.vaultState.items[index] = nextItem;
      this.vaultState.items = this.vaultState.items.slice();
      this.vaultState.detailMessage = nextStatus === 'verified' ? 'Verified. Trusted preview unlocked.' :
        'Hash mismatch. Restore clean file to recover.';
      this.vaultState.detailPreview = nextStatus === 'verified' ? this.readPreview(item.filePath) : '';
    } catch (error) {
      const nextItem = this.copyItem(item);
      nextItem.lastVerificationStatus = 'error';
      nextItem.lastVerificationTime = new Date().toLocaleString();
      this.vaultState.items[index] = nextItem;
      this.vaultState.items = this.vaultState.items.slice();
      this.vaultState.detailMessage = `Verification failed explicitly: ${(error as Error).message}`;
      this.vaultState.detailPreview = '';
    }
  }

  private openItemFromHome(itemId: string): void {
    this.vaultState.selectedItemId = itemId;
    this.vaultState.detailPreview = '';
    this.verifyAndRefresh(itemId);
    this.pathStack.pushPath({ name: ROUTE_DETAIL });
  }

  private getSelectedItem(): VaultItem | undefined {
    return this.vaultState.items.find((current: VaultItem) => current.id === this.vaultState.selectedItemId);
  }

  @Builder
  private pageMap(name: string) {
    if (name === ROUTE_HOME) {
      VaultHomePage({
        openItemAction: (itemId: string) => this.openItemFromHome(itemId),
        openStorageAction: () => this.pathStack.pushPath({ name: ROUTE_STORAGE }),
        vaultState: this.vaultState
      })
    } else if (name === ROUTE_DETAIL) {
      VaultDetailPage({
        vaultState: this.vaultState,
        verifyAction: () => this.verifyAndRefresh(this.vaultState.selectedItemId),
        raiseLabelAction: () => this.raiseLabel(this.vaultState.selectedItemId),
        tamperAction: () => this.tamperItem(this.vaultState.selectedItemId),
        recreateAction: () => this.rewriteFromSeed(this.vaultState.selectedItemId),
        canOperateOnFile: this.getSelectedItem() !== undefined && this.getSelectedItem()!.filePath.length > 0
      })
    } else if (name === ROUTE_STORAGE) {
      StorageDiagnosticsPage({
        vaultState: this.vaultState,
        loadAction: () => this.loadStorageDiagnostics()
      })
    }
  }
}
