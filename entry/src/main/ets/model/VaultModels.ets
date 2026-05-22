export type VaultCategory = 'emergency_contact' | 'medical_id' | 'insurance_card';

export type SecurityLabelLevel = 's0' | 's1' | 's2' | 's3' | 's4';

export type VerificationStatus = 'unknown' | 'verified' | 'mismatch' | 'error';

export interface VaultRecordSeed {
  id: string;
  category: VaultCategory;
  title: string;
  fileName: string;
  summaryLine: string;
  recommendedSecurityLabel: SecurityLabelLevel;
  templateContent: string;
  contentType: 'application/json' | 'text/plain';
}

export interface VaultItem {
  id: string;
  category: VaultCategory;
  title: string;
  fileName: string;
  filePath: string;
  fileUri: string;
  expectedSha256: string;
  currentSecurityLabel: SecurityLabelLevel;
  recommendedSecurityLabel: SecurityLabelLevel;
  lastVerificationStatus: VerificationStatus;
  lastVerificationTime?: string;
  summaryLine: string;
}

export const SAMPLE_RECORD_SEEDS: VaultRecordSeed[] = [
  {
    id: 'emergency-contact',
    category: 'emergency_contact',
    title: 'Primary Emergency Contact',
    fileName: 'emergency-contact.json',
    summaryLine: 'Avery Chen · +1-555-0100',
    recommendedSecurityLabel: 's2',
    contentType: 'application/json',
    templateContent: JSON.stringify({
      'contactName': 'Avery Chen',
      'relationship': 'Spouse',
      'primaryPhone': '+1-555-0100',
      'secondaryPhone': '+1-555-0101',
      'notes': 'Call first in case of fall or chest pain.'
    })
  },
  {
    id: 'medical-profile',
    category: 'medical_id',
    title: 'Medical Profile',
    fileName: 'medical-profile.json',
    summaryLine: 'Blood: O+ · Allergy: Penicillin',
    recommendedSecurityLabel: 's3',
    contentType: 'application/json',
    templateContent: JSON.stringify({
      'fullName': 'Avery Chen',
      'bloodType': 'O+',
      'allergies': ['Penicillin'],
      'conditions': ['Asthma'],
      'medications': ['Albuterol inhaler'],
      'emergencyNotes': 'Uses rescue inhaler during attacks.'
    })
  },
  {
    id: 'insurance-card',
    category: 'insurance_card',
    title: 'Insurance Card',
    fileName: 'insurance-card.txt',
    summaryLine: 'Harmony Health · Member HH-4839201',
    recommendedSecurityLabel: 's3',
    contentType: 'text/plain',
    templateContent: `Provider: Harmony Health
    Member ID: HH-4839201
    Group ID: GH-2041
    Rx BIN: 019876
    Support Phone: +1-555-0199`
  }
];
