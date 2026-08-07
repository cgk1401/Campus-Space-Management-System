"""
14-data-generator-G10: Synthetic Data Generator
CS486 Midterm Project - Campus Space Management System (Group G10)

Generates 100,000 to 500,000 realistic booking records spanning 3 academic years
(2023-09-01 to 2026-08-31) into T-SQL batch files.
Includes maintenance (OutOfService & Advisory), cancellations, no-shows,
and advisory acknowledgements.
"""

import os
import random
from datetime import datetime, timedelta

# Configuration
TOTAL_BOOKINGS = 100000  # Default 100,000 (can be increased to 500,000)
BATCH_SIZE = 5000        # Rows per SQL insert batch file
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
SQL_BATCH_DIR = os.path.join(OUTPUT_DIR, "sql_batches")

# Date range: 3 academic years (Sep 2023 - Aug 2026)
START_DATE = datetime(2023, 9, 1, 7, 0, 0)
END_DATE = datetime(2026, 8, 31, 21, 0, 0)

# Reference values
ROLES = ['Student', 'Lecturer', 'TeachingAssistant', 'FacilityStaff', 'DepartmentAdministrator', 'FacilityManager']
ROLE_WEIGHTS = [0.75, 0.15, 0.05, 0.03, 0.01, 0.01]

DEPARTMENTS = ['Computer Science', 'Information Technology', 'Software Engineering', 'Data Science', 'Cyber Security']

SPACE_TYPES = ['Auditorium', 'Classroom', 'ComputerLaboratory', 'ProjectLaboratory', 'MeetingRoom', 'StudentWorkspace']

BUILDINGS = ['Building A', 'Building B', 'Building C', 'Building D', 'Building E']

PURPOSES = ['Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'StudentActivity', 'AdministrativeEvent']
PURPOSE_WEIGHTS = [0.40, 0.15, 0.15, 0.10, 0.10, 0.07, 0.03]

STATUSES = ['Completed', 'Rejected', 'Cancelled', 'NoShow', 'CheckedIn', 'Approved', 'Pending']
STATUS_WEIGHTS = [0.60, 0.12, 0.10, 0.08, 0.04, 0.03, 0.03]

FIRST_NAMES = ['An', 'Binh', 'Cuong', 'Dung', 'Em', 'Giang', 'Hoa', 'Hung', 'Khai', 'Linh', 'Minh', 'Nam', 'Phuong', 'Quang', 'Sonn', 'Trang', 'Tuan', 'Viet', 'Yen']
LAST_NAMES = ['Nguyen', 'Tran', 'Le', 'Pham', 'Hoang', 'Huynh', 'Vu', 'Vo', 'Dang', 'Bui', 'Do', 'Hye', 'Ngo', 'Duong', 'Ly']

def random_name():
    return f"{random.choice(LAST_NAMES)} {random.choice(FIRST_NAMES)}"

def ensure_dirs():
    if not os.path.exists(SQL_BATCH_DIR):
        os.makedirs(SQL_BATCH_DIR)

def generate_users(num_users=2000):
    users = []
    # System Auto-Approval Actor is pre-created in migration (-1)
    for i in range(1, num_users + 1):
        role = random.choices(ROLES, weights=ROLE_WEIGHTS)[0]
        dept = random.choice(DEPARTMENTS)
        status = 'Active' if random.random() > 0.05 else 'Disabled'
        name = random_name()
        email = f"user{i}.{name.lower().replace(' ', '.')}@campus.edu.vn"
        phone = f"09{random.randint(10000000, 99999999)}"
        users.append({
            'UserID': i,
            'FullName': name,
            'Email': email,
            'PhoneNumber': phone,
            'Role': role,
            'Department': dept,
            'AccountStatus': status
        })
    return users

def generate_spaces():
    spaces = []
    space_id = 1
    for b in BUILDINGS:
        for f in range(1, 6):  # 5 floors
            for r in range(1, 6):  # 5 rooms per floor
                code = f"{b[9]}-{f}0{r}"
                stype = random.choice(SPACE_TYPES)
                capacity = 200 if stype == 'Auditorium' else (40 if 'Lab' in stype else random.randint(15, 60))
                status = 'Available' if random.random() > 0.08 else random.choice(['UnderMaintenance', 'TemporarilyClosed'])
                spaces.append({
                    'SpaceCode': code,
                    'SpaceName': f"{stype} {f}0{r}",
                    'SpaceType': stype,
                    'Building': b,
                    'Floor': f,
                    'RoomNumber': f"{f}0{r}",
                    'Capacity': capacity,
                    'CurrentStatus': status,
                    'UsagePolicy': 'Standard campus usage guidelines apply.'
                })
                space_id += 1
    return spaces

def generate_facilities(spaces):
    facilities = []
    fac_id = 1
    fac_names = ['Projector', 'Whiteboard', 'Microphone', 'Computer', 'LivestreamingEquipment', 'AirConditioner']
    for sp in spaces:
        # Give each space 2 to 4 facilities
        num_f = random.randint(2, 4)
        selected = random.sample(fac_names, num_f)
        for f_name in selected:
            facilities.append({
                'FacilityID': fac_id,
                'FacilityName': f_name,
                'SpaceCode': sp['SpaceCode']
            })
            fac_id += 1
    return facilities

def generate_maintenance(spaces, num_records=2500):
    maint_records = []
    for i in range(1, num_records + 1):
        sp = random.choice(spaces)
        reporter_id = random.randint(1, 500)
        assigned_id = random.randint(501, 600)
        start_ts = START_DATE + timedelta(seconds=random.randint(0, int((END_DATE - START_DATE).total_seconds())))
        duration_hours = random.randint(2, 72)
        end_ts = start_ts + timedelta(hours=duration_hours)
        status = 'Closed' if end_ts < datetime.now() else random.choice(['Open', 'InProgress', 'Resolved'])
        impact = 'Advisory' if random.random() > 0.4 else 'OutOfService'
        
        maint_records.append({
            'MaintenanceID': i,
            'SpaceCode': sp['SpaceCode'],
            'FacilityID': 'NULL',
            'ReporterID': reporter_id,
            'AssignedStaffID': assigned_id,
            'ProblemDescription': f"Routine maintenance / repair job #{i}",
            'StartTime': start_ts.strftime('%Y-%m-%d %H:%M:%S'),
            'CompletionTime': f"'{end_ts.strftime('%Y-%m-%d %H:%M:%S')}'" if status in ['Closed', 'Resolved'] else 'NULL',
            'Status': status,
            'ImpactLevel': impact
        })
    return maint_records

def main():
    ensure_dirs()
    print("Generating base seed entities (Users, Spaces, Facilities, Maintenance)...")
    users = generate_users(3000)
    spaces = generate_spaces()
    facilities = generate_facilities(spaces)
    maintenance = generate_maintenance(spaces, 3000)

    # 1. Master Seed SQL File
    master_sql_path = os.path.join(SQL_BATCH_DIR, "00_master_seed.sql")
    with open(master_sql_path, "w", encoding="utf-8") as f:
        f.write("-- Master Seed File for CampusSpaceManagement\nUSE CampusSpaceManagement;\nGO\n\n")
        
        # Users
        f.write("SET IDENTITY_INSERT [User] ON;\n")
        f.write("INSERT INTO [User] (UserID, FullName, Email, PhoneNumber, Role, Department, AccountStatus) VALUES\n")
        u_vals = [f"({u['UserID']}, N'{u['FullName']}', '{u['Email']}', '{u['PhoneNumber']}', '{u['Role']}', N'{u['Department']}', '{u['AccountStatus']}')" for u in users]
        f.write(",\n".join(u_vals) + ";\n")
        f.write("SET IDENTITY_INSERT [User] OFF;\nGO\n\n")
        
        # Spaces
        f.write("INSERT INTO [Space] (SpaceCode, SpaceName, SpaceType, Building, Floor, RoomNumber, Capacity, CurrentStatus, UsagePolicy) VALUES\n")
        s_vals = [f"('{s['SpaceCode']}', N'{s['SpaceName']}', '{s['SpaceType']}', '{s['Building']}', {s['Floor']}, '{s['RoomNumber']}', {s['Capacity']}, '{s['CurrentStatus']}', N'{s['UsagePolicy']}')" for s in spaces]
        f.write(",\n".join(s_vals) + ";\nGO\n\n")

        # Facilities
        f.write("SET IDENTITY_INSERT Facility ON;\n")
        f.write("INSERT INTO Facility (FacilityID, FacilityName, SpaceCode) VALUES\n")
        fac_vals = [f"({fc['FacilityID']}, '{fc['FacilityName']}', '{fc['SpaceCode']}')" for fc in facilities]
        f.write(",\n".join(fac_vals) + ";\n")
        f.write("SET IDENTITY_INSERT Facility OFF;\nGO\n\n")

        # Maintenance
        f.write("SET IDENTITY_INSERT MaintenanceRecord ON;\n")
        f.write("INSERT INTO MaintenanceRecord (MaintenanceID, SpaceCode, FacilityID, ReporterID, AssignedStaffID, ProblemDescription, StartTime, CompletionTime, Status, ImpactLevel) VALUES\n")
        m_vals = [f"({m['MaintenanceID']}, '{m['SpaceCode']}', {m['FacilityID']}, {m['ReporterID']}, {m['AssignedStaffID']}, N'{m['ProblemDescription']}', '{m['StartTime']}', {m['CompletionTime']}, '{m['Status']}', '{m['ImpactLevel']}')" for m in maintenance]
        f.write(",\n".join(m_vals) + ";\n")
        f.write("SET IDENTITY_INSERT MaintenanceRecord OFF;\nGO\n\n")

    print("Master seed generated successfully.")
    print(f"Generating {TOTAL_BOOKINGS} BookingRequests & related lifecycle tables in batches of {BATCH_SIZE}...")

    # 2. Generating Booking Requests
    total_batches = (TOTAL_BOOKINGS + BATCH_SIZE - 1) // BATCH_SIZE
    booking_id = 1

    for b_idx in range(total_batches):
        batch_filename = os.path.join(SQL_BATCH_DIR, f"01_bookings_batch_{b_idx+1:02d}.sql")
        bookings = []
        approvals = []
        sessions = []
        acknowledgements = []

        batch_end = min(booking_id + BATCH_SIZE, TOTAL_BOOKINGS + 1)
        for b_id in range(booking_id, batch_end):
            requester_id = random.randint(1, len(users))
            sp = random.choice(spaces)
            purpose = random.choices(PURPOSES, weights=PURPOSE_WEIGHTS)[0]
            status = random.choices(STATUSES, weights=STATUS_WEIGHTS)[0]
            
            # Start time within 3 years
            start_ts = START_DATE + timedelta(seconds=random.randint(0, int((END_DATE - START_DATE).total_seconds())))
            duration_hours = random.choice([1, 2, 3, 4])
            end_ts = start_ts + timedelta(hours=duration_hours)
            expected = random.randint(5, sp['Capacity'])

            bookings.append(f"({b_id}, {requester_id}, '{sp['SpaceCode']}', '{start_ts.strftime('%Y-%m-%d %H:%M:%S')}', '{end_ts.strftime('%Y-%m-%d %H:%M:%S')}', '{purpose}', {expected}, '{status}')")

            # Approvals
            if status in ['Approved', 'Rejected', 'CheckedIn', 'Completed', 'NoShow']:
                approver_id = -1 if random.random() > 0.5 else random.randint(1, 100) # System Auto or Staff
                dec_time = start_ts - timedelta(hours=random.randint(1, 48))
                note = "System Auto-Approved" if approver_id == -1 else "Approved by department admin"
                rej_reason = "NULL" if status != 'Rejected' else "N'Space unavailable or conflicting schedule'"
                approvals.append(f"({b_id}, {approver_id}, '{dec_time.strftime('%Y-%m-%d %H:%M:%S')}', N'{note}', {rej_reason})")

            # Usage Sessions
            if status in ['CheckedIn', 'Completed']:
                checkin_staff = random.randint(1, 100)
                act_start = start_ts + timedelta(minutes=random.randint(-10, 15))
                act_end = f"'{end_ts.strftime('%Y-%m-%d %H:%M:%S')}'" if status == 'Completed' else 'NULL'
                sessions.append(f"({b_id}, {b_id}, '{act_start.strftime('%Y-%m-%d %H:%M:%S')}', {checkin_staff}, N'Normal condition', {act_end}, N'Clean', N'No issues')")

            # Booking Acknowledgements (sample simulation for advisory)
            if random.random() < 0.05: # 5% advisory acknowledgement
                maint_id = random.randint(1, len(maintenance))
                ack_by = requester_id
                ack_time = start_ts - timedelta(hours=random.randint(1, 24))
                acknowledgements.append(f"({b_id}, {maint_id}, '{ack_time.strftime('%Y-%m-%d %H:%M:%S')}', {ack_by})")

        # Write Batch SQL
        with open(batch_filename, "w", encoding="utf-8") as f:
            f.write(f"-- Booking Batch {b_idx+1}/{total_batches}\nUSE CampusSpaceManagement;\nGO\n\n")
            
            # BookingRequest
            f.write("SET IDENTITY_INSERT BookingRequest ON;\n")
            f.write("INSERT INTO BookingRequest (BookingID, RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status) VALUES\n")
            f.write(",\n".join(bookings) + ";\n")
            f.write("SET IDENTITY_INSERT BookingRequest OFF;\nGO\n\n")

            # Approval
            if approvals:
                f.write("INSERT INTO Approval (BookingID, ApproverID, DecisionTime, DecisionNote, RejectionReason) VALUES\n")
                f.write(",\n".join(approvals) + ";\nGO\n\n")

            # UsageSession
            if sessions:
                f.write("INSERT INTO UsageSession (BookingID, ApprovalID, ActualStartTime, CheckInStaffID, InitialCondition, ActualEndTime, FinalCondition, UsageNotes) VALUES\n")
                f.write(",\n".join(sessions) + ";\nGO\n\n")

            # BookingAcknowledgement
            if acknowledgements:
                f.write("INSERT INTO BookingAcknowledgement (BookingID, MaintenanceID, AcknowledgedAt, AcknowledgedByUserID) VALUES\n")
                f.write(",\n".join(acknowledgements) + ";\nGO\n\n")

        print(f"Batch {b_idx+1}/{total_batches} generated.")

    print("\nData generation completed successfully!")

if __name__ == "__main__":
    main()
