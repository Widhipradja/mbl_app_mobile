/// An answer shaped like the plan's `GET /api/m/v1/dashboard`.
Map<String, dynamic> ringkasanAnswer({
  Map<String, dynamic>? finance,
  Map<String, dynamic>? members,
  Map<String, dynamic>? shodaqoh,
  Map<String, dynamic>? jimpitan,
}) =>
    {
      'month': '2026-11',
      'finance': finance ??
          {
            'data': {
              'balance': '22863820',
              'income': '849953804',
              'expense': '827089984',
              'as_of': '2026-09-02',
              'recent_transactions': [
                {
                  'id': 't1',
                  'date': '2026-09-02',
                  'description': 'Infaq Jumat',
                  'type': 'income',
                  'amount': '150000'
                },
                {
                  'id': 't2',
                  'date': '2026-09-01',
                  'description': 'Listrik',
                  'type': 'expense',
                  'amount': '75000.5'
                },
              ],
              'funds': {
                'as_of': '2026-11-23',
                'total_balance': '1500',
                'items': [
                  {
                    'key': 'operasional',
                    'name': 'Operasional',
                    'income': '900',
                    'expense': '400',
                    'balance': '500'
                  },
                ],
              },
            },
          },
      'members': members ??
          {
            'data': {
              'total_members': 120,
              'active_members': 110,
              'new_this_month': 3,
              'total_families': 40,
              'gender': {'male': 60, 'female': 60},
              'age_groups': [
                {'label': '0-17', 'total': 30},
                {'label': '18-40', 'total': 50},
              ],
            },
          },
      'shodaqoh': shodaqoh ??
          {
            'data': {'participation_count': 45, 'total_members': 120},
          },
      'jimpitan': jimpitan ??
          {
            'data': {
              'month': '2026-11',
              'total': '1250000',
              'setoran_total': '1000000',
              'kas_total': '250000',
              'contributors': 12,
              'items': [
                {
                  'label': 'Setoran',
                  'date': '2026-11-20',
                  'amount': '600000',
                  'kind': 'setoran'
                },
                {
                  'label': 'Jimpitan Oktober',
                  'date': '',
                  'amount': '150000',
                  'kind': 'kas'
                },
              ],
            },
          },
    };

