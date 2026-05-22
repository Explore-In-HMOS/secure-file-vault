import { type VaultItem } from '../model/VaultModels';

export interface StorageSnapshot {
  appSize?: number;
  cacheSize?: number;
  dataSize?: number;
  builtInFreeSize?: number;
  builtInTotalSize?: number;
  fileSystemFreeSize?: number;
  fileSystemTotalSize?: number;
  builtInError?: string;
  fileSystemFreeError?: string;
  fileSystemTotalError?: string;
}

export interface VaultHealthSummary {
  total: number;
  verified: number;
  unknown: number;
  mismatch: number;
  error: number;
}

@Observed
export class VaultPageState {
  items: VaultItem[] = [];
  detailMessage: string = 'Setup not started.';
  storageMessage: string = 'Diagnostics not loaded.';
  storageSnapshot: StorageSnapshot = {};
  selectedItemId: string = '';
  detailPreview: string = '';
  detailResolvedPath: string = 'pending setup';
  setupCompleted: boolean = false;

  constructor(items: VaultItem[]) {
    this.items = items;
  }
}
