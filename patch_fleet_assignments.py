import re

file_path = 'lib/presentation/screens/fleet_assignments_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# 1. Add enum
content = re.sub(
    r'class FleetAssignmentsScreen extends ConsumerStatefulWidget \{',
    'enum AssignmentFilter { all, unassigned, assigned }\n\nclass FleetAssignmentsScreen extends ConsumerStatefulWidget {',
    content
)

# 2. Change state variable
content = re.sub(
    r'bool _showUnassignedOnly = false;',
    'AssignmentFilter _assignmentFilter = AssignmentFilter.all;',
    content
)

# 3. Update filtering logic in `data: (bookings) {`
old_filtering = """        final filteredBookings = bookings.where((b) {
          final matchesSearch = b.customerName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              b.bookingNumber.contains(_searchQuery) ||
              b.service.toLowerCase().contains(_searchQuery.toLowerCase());
          final hasArtists = b.assignedStaff.isNotEmpty;
          final isConfirmedOrCompleted =
              b.status.toLowerCase() == 'confirmed' ||
                  b.status.toLowerCase() == 'completed';
          final matchesUnassigned =
              !_showUnassignedOnly || (b.driverId.isEmpty && b.vehicleId.isEmpty);
          final matchesMonth = !_filterByMonth ||
              (b.serviceStart.year == _selectedMonth.year &&
                  b.serviceStart.month == _selectedMonth.month);

          return matchesSearch &&
              hasArtists &&
              isConfirmedOrCompleted &&
              matchesUnassigned &&
              matchesMonth;
        }).toList()
          ..sort((a, b) => b.serviceStart.compareTo(a.serviceStart));"""

new_filtering = """        final baseFilteredBookings = bookings.where((b) {
          final matchesSearch = b.customerName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              b.bookingNumber.contains(_searchQuery) ||
              b.service.toLowerCase().contains(_searchQuery.toLowerCase());
          final hasArtists = b.assignedStaff.isNotEmpty;
          final isConfirmedOrCompleted =
              b.status.toLowerCase() == 'confirmed' ||
                  b.status.toLowerCase() == 'completed';
          final matchesMonth = !_filterByMonth ||
              (b.serviceStart.year == _selectedMonth.year &&
                  b.serviceStart.month == _selectedMonth.month);

          return matchesSearch &&
              hasArtists &&
              isConfirmedOrCompleted &&
              matchesMonth;
        }).toList();

        final unassignedCount = baseFilteredBookings.where((b) => b.driverId.isEmpty && b.vehicleId.isEmpty).length;
        final assignedCount = baseFilteredBookings.where((b) => b.driverId.isNotEmpty || b.vehicleId.isNotEmpty).length;
        final allCount = baseFilteredBookings.length;

        final filteredBookings = baseFilteredBookings.where((b) {
          if (_assignmentFilter == AssignmentFilter.unassigned) {
            return b.driverId.isEmpty && b.vehicleId.isEmpty;
          } else if (_assignmentFilter == AssignmentFilter.assigned) {
            return b.driverId.isNotEmpty || b.vehicleId.isNotEmpty;
          }
          return true;
        }).toList()
          ..sort((a, b) => b.serviceStart.compareTo(a.serviceStart));"""

content = content.replace(old_filtering, new_filtering)

# 4. Mobile toggle logic update
mobile_toggle_old = """                    // Unassigned-only toggle
                    GestureDetector(
                      onTap: () => setState(() {
                        _showUnassignedOnly = !_showUnassignedOnly;
                        _activeBookingId = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: _showUnassignedOnly
                              ? crmColors.warning.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.pending_actions_outlined,
                          size: 18,
                          color: _showUnassignedOnly ? crmColors.warning : crmColors.textSecondary,
                        ),
                      ),
                    ),"""

mobile_toggle_new = """                    // Unassigned toggle (mobile)
                    GestureDetector(
                      onTap: () => setState(() {
                        _assignmentFilter = _assignmentFilter == AssignmentFilter.unassigned 
                          ? AssignmentFilter.all 
                          : AssignmentFilter.unassigned;
                        _activeBookingId = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: _assignmentFilter == AssignmentFilter.unassigned
                              ? crmColors.warning.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.pending_actions_outlined,
                          size: 18,
                          color: _assignmentFilter == AssignmentFilter.unassigned ? crmColors.warning : crmColors.textSecondary,
                        ),
                      ),
                    ),"""

content = content.replace(mobile_toggle_old, mobile_toggle_new)

# 5. Active filter pill logic update
pill_old = """              if (_showUnassignedOnly)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: crmColors.warning.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: crmColors.warning.withValues(alpha: 0.30)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pending_actions_outlined,
                                size: 11, color: crmColors.warning),
                            4.w,
                            Text(
                              'Unassigned only',
                              style: TextStyle(
                                fontSize: 11,
                                color: crmColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            6.w,
                            GestureDetector(
                              onTap: () => setState(() {
                                _showUnassignedOnly = false;
                                _activeBookingId = null;
                              }),
                              child: Icon(Icons.close, size: 12, color: crmColors.warning),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),"""

pill_new = """              if (_assignmentFilter != AssignmentFilter.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: crmColors.warning.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: crmColors.warning.withValues(alpha: 0.30)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pending_actions_outlined,
                                size: 11, color: crmColors.warning),
                            4.w,
                            Text(
                              _assignmentFilter == AssignmentFilter.unassigned ? 'Unassigned only' : 'Assigned only',
                              style: TextStyle(
                                fontSize: 11,
                                color: crmColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            6.w,
                            GestureDetector(
                              onTap: () => setState(() {
                                _assignmentFilter = AssignmentFilter.all;
                                _activeBookingId = null;
                              }),
                              child: Icon(Icons.close, size: 12, color: crmColors.warning),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),"""

content = content.replace(pill_old, pill_new)


# 6. Replace Desktop Card logic with unified Row
desktop_old = """              // Desktop Search and filters
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search by client name, reference, service...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      16.w,
                      Row(
                        children: [
                          Checkbox(
                            value: _showUnassignedOnly,
                            onChanged: (val) {
                              setState(() {
                                _showUnassignedOnly = val ?? false;
                                _activeBookingId = null;
                              });
                            },
                          ),
                          const Text(
                            'Unassigned Only',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              16.h,

              // Month Selector / Navigation Header Card (Desktop)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: crmColors.border),
                ),
                color: crmColors.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous Month',
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                              1,
                            );
                            _activeBookingId = null;
                          });
                        },
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedMonth,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDatePickerMode: DatePickerMode.year,
                            helpText: 'Select Month & Year',
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedMonth = DateTime(picked.year, picked.month, 1);
                              _activeBookingId = null;
                            });
                          }
                        },
                        icon: Icon(Icons.calendar_month, color: crmColors.primary, size: 20),
                        label: Text(
                          _formatMonthYear(_selectedMonth),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: crmColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next Month',
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                            );
                            _activeBookingId = null;
                          });
                        },
                      ),
                      const Spacer(),
                      FilterChip(
                        selected: _filterByMonth,
                        label: const Text('Filter by Month'),
                        onSelected: (val) {
                          setState(() {
                            _filterByMonth = val;
                            _activeBookingId = null;
                          });
                        },
                        selectedColor: crmColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: crmColors.primary,
                        labelStyle: TextStyle(
                          color: _filterByMonth ? crmColors.primary : crmColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),"""

desktop_new = """              // Desktop Search, Filter, and Month Navigation
              Row(
                children: [
                  // Search
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: crmColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: crmColors.border),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by client, reference...',
                          hintStyle: TextStyle(fontSize: 14, color: crmColors.textSecondary),
                          prefixIcon: Icon(Icons.search, size: 20, color: crmColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ),
                  16.w,
                  
                  // Segmented Filter
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: crmColors.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSegmentTab('All $allCount', AssignmentFilter.all, crmColors),
                        _buildSegmentTab('Unassigned $unassignedCount', AssignmentFilter.unassigned, crmColors),
                        _buildSegmentTab('Assigned $assignedCount', AssignmentFilter.assigned, crmColors),
                      ],
                    ),
                  ),
                  16.w,

                  // Month Navigation
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: crmColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: crmColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, size: 20, color: crmColors.textSecondary),
                          tooltip: 'Previous Month',
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                            _activeBookingId = null;
                            _filterByMonth = true;
                          }),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedMonth,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              helpText: 'Select Month & Year',
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedMonth = DateTime(picked.year, picked.month, 1);
                                _activeBookingId = null;
                                _filterByMonth = true;
                              });
                            }
                          },
                          icon: Icon(Icons.calendar_month, color: crmColors.textPrimary, size: 18),
                          label: Text(
                            _formatMonthYear(_selectedMonth),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: crmColors.textPrimary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, size: 20, color: crmColors.textSecondary),
                          tooltip: 'Next Month',
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                            _activeBookingId = null;
                            _filterByMonth = true;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),"""

content = content.replace(desktop_old, desktop_new)

# 7. Add `_buildSegmentTab` at the bottom of the state class safely
build_tab_code = """
  Widget _buildSegmentTab(String text, AssignmentFilter filter, CrmTheme crmColors) {
    final isSelected = _assignmentFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _assignmentFilter = filter;
          _activeBookingId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? crmColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? crmColors.textPrimary : crmColors.textSecondary,
          ),
        ),
      ),
    );
  }
}"""

# Replace ONLY the last '}' with the new code
last_brace_index = content.rfind('}')
if last_brace_index != -1:
    content = content[:last_brace_index] + build_tab_code + content[last_brace_index+1:]

with open(file_path, 'w') as f:
    f.write(content)

print("Patch applied")
