import { SAMPLE_RECORD_SEEDS, type SecurityLabelLevel, type VaultItem } from '../model/VaultModels';
import { type VaultHealthSummary } from '../state/VaultPageState';

export function createInitialVaultItems(): VaultItem[] {
  return SAMPLE_RECORD_SEEDS.map((seed) => {
    const item: VaultItem = {
      id: seed.id,
      category: seed.category,
      title: seed.title,
      fileName: seed.fileName,
      filePath: '',
      fileUri: '',
      expectedSha256: '',
      currentSecurityLabel: 's3',
      recommendedSecurityLabel: seed.recommendedSecurityLabel,
      lastVerificationStatus: 'unknown',
      summaryLine: seed.summaryLine
    };
    return item;
  });
}

export function formatBytes(size?: number): string {
  if (size === undefined || size < 0) {
    return 'n/a';
  }
  if (size < 1024) {
    return `${size} B`;
  }
  return `${(size / 1024 / 1024).toFixed(2)} MB`;
}

export function summarizeVaultHealth(items: VaultItem[]): VaultHealthSummary {
  return {
    total: items.length,
    verified: items.filter((item) => item.lastVerificationStatus === 'verified').length,
    unknown: items.filter((item) => item.lastVerificationStatus === 'unknown').length,
    mismatch: items.filter((item) => item.lastVerificationStatus === 'mismatch').length,
    error: items.filter((item) => item.lastVerificationStatus === 'error').length
  };
}

export function statusColor(status: string): string {
  if (status === 'verified') {
    return '#7CE5A7';
  }
  if (status === 'mismatch' || status === 'error') {
    return '#FF9E8D';
  }
  return '#E8B17A';
}

export function labelRank(label: SecurityLabelLevel): number {
  if (label === 's0') {
    return 0;
  }
  if (label === 's1') {
    return 1;
  }
  if (label === 's2') {
    return 2;
  }
  if (label === 's3') {
    return 3;
  }
  return 4;
}

export function normalizeSecurityLabel(value: string, fallback: SecurityLabelLevel): SecurityLabelLevel {
  if (value === 's0' || value === 's1' || value === 's2' || value === 's3' || value === 's4') {
    return value as SecurityLabelLevel;
  }
  return fallback;
}

export function nextSecurityLabel(label: SecurityLabelLevel): SecurityLabelLevel {
  if (label === 's0') {
    return 's1';
  }
  if (label === 's1') {
    return 's2';
  }
  if (label === 's2') {
    return 's3';
  }
  if (label === 's3') {
    return 's4';
  }
  return 's4';
}

export function demoRecommendedLabel(current: SecurityLabelLevel,
  seedRecommended: SecurityLabelLevel): SecurityLabelLevel {
  if (labelRank(current) < labelRank(seedRecommended)) {
    return seedRecommended;
  }
  return nextSecurityLabel(current);
}

export function canRaiseSecurityLabel(item?: VaultItem): boolean {
  if (!item) {
    return false;
  }
  return labelRank(item.currentSecurityLabel) < labelRank(item.recommendedSecurityLabel);
}

export function labelActionText(item?: VaultItem): string {
  if (!item) {
    return 'Label unavailable';
  }
  if (canRaiseSecurityLabel(item)) {
    return `Raise to ${item.recommendedSecurityLabel}`;
  }
  if (labelRank(item.currentSecurityLabel) === labelRank(item.recommendedSecurityLabel)) {
    if (item.currentSecurityLabel === 's4') {
      return 'Max s4';
    }
    return `At ${item.currentSecurityLabel}`;
  }
  return 'Cannot lower label';
}

export function labelActionHint(item?: VaultItem): string {
  if (!item) {
    return 'Open a record first.';
  }
  if (canRaiseSecurityLabel(item)) {
    return `Tap Raise to move ${item.currentSecurityLabel} up to ${item.recommendedSecurityLabel}.`;
  }
  if (labelRank(item.currentSecurityLabel) === labelRank(item.recommendedSecurityLabel)) {
    if (item.currentSecurityLabel === 's4') {
      return 'Already at highest security label: s4.';
    }
    return `At required label: ${item.currentSecurityLabel}. s4 is higher but not needed here.`;
  }
  return `${item.currentSecurityLabel} is above target ${item.recommendedSecurityLabel}; API cannot lower labels.`;
}

export function shortPath(path: string): string {
  if (!path) {
    return 'not ready';
  }
  const parts: string[] = path.split('/');
  return parts[parts.length - 1];
}

export function shortHash(hashText: string): string {
  if (hashText.length <= 12) {
    return hashText || 'not ready';
  }
  return `${hashText.slice(0, 6)}…${hashText.slice(hashText.length - 4)}`;
}
