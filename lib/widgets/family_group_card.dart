import 'package:flutter/material.dart';
import '../models/member.dart';

class FamilyGroupCard extends StatelessWidget {
  final String familyId;
  final List<Member> familyMembers;
  final bool isNoFamily;
  final Function(Member member) onEditMember;
  final Function(Member member) onDeleteMember;
  final Function({String? familyId}) onAddFamilyMember;

  const FamilyGroupCard({
    super.key,
    required this.familyId,
    required this.familyMembers,
    required this.isNoFamily,
    required this.onEditMember,
    required this.onDeleteMember,
    required this.onAddFamilyMember,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isNoFamily)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.family_restroom,
                    size: 20,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Family Group',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    color: Colors.blue[700],
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Add family member',
                    onPressed: () => onAddFamilyMember(familyId: familyId),
                  ),
                ],
              ),
            ),
          // Non-children section (anyone whose relationship is not 'Anak')
          ...familyMembers
              .where((m) => m.relationship != 'Anak')
              .map(
                (member) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member.gender == 'male'
                        ? Colors.blue[100]
                        : Colors.pink[100],
                    child: Text(
                      member.fullName.isNotEmpty
                          ? member.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: member.gender == 'male'
                            ? Colors.blue[700]
                            : Colors.pink[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      if (member.isHeadOfFamily)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HEAD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          member.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (member.surname.isNotEmpty)
                        Text('Surname: ${member.surname}'),
                      if (member.relationship.isNotEmpty &&
                          !member.isHeadOfFamily)
                        Text('Relationship: ${member.relationship}'),
                      Text(member.email),
                      if (member.phone.isNotEmpty) Text(member.phone),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEditMember(member);
                      } else if (value == 'delete') {
                        onDeleteMember(member);
                      }
                    },
                  ),
                ),
              ),
          // Children section (relationship == 'Anak')
          if (familyMembers.any((m) => m.relationship == 'Anak'))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!, width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.child_care,
                          size: 18,
                          color: Colors.purple[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Children',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...familyMembers
                      .where((m) => m.relationship == 'Anak')
                      .map(
                        (member) => Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.purple[100]!,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: member.gender == 'male'
                                  ? Colors.purple[100]
                                  : Colors.pink[100],
                              child: Icon(
                                member.category == 'Balita'
                                    ? Icons.child_care
                                    : (member.gender == 'male'
                                          ? Icons.boy
                                          : Icons.girl),
                                size: 16,
                                color: member.gender == 'male'
                                    ? Colors.purple[700]
                                    : Colors.pink[700],
                              ),
                            ),
                            title: Text(
                              member.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Colors.purple[900],
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (member.surname.isNotEmpty)
                                  Text(
                                    'Surname: ${member.surname}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (member.relationship.isNotEmpty)
                                  Text(
                                    'Relationship: ${member.relationship}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (member.email.isNotEmpty)
                                  Text(
                                    member.email,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (member.phone.isNotEmpty)
                                  Text(
                                    member.phone,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  onEditMember(member);
                                } else if (value == 'delete') {
                                  onDeleteMember(member);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
