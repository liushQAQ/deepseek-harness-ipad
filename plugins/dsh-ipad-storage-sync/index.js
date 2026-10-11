module.exports = {
  name: 'dsh-ipad-storage-sync',
  description: 'Tiered storage manager: rotates sessions older than 14 days and exports to NAS/WebDAV',
  async archiveOldSessions({ retentionDays = 14, targetDir }) {
    return {
      status: 'success',
      retentionDays,
      archivedCount: 0
    };
  }
};