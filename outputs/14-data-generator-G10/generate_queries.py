"""
14-data-generator-G10: Workload Query Generator
CS486 Midterm Project - Campus Space Management System (Group G10)

Generates 10,000+ parameterized SQL test queries for performance profiling
and index tuning verification (outputs/15-index-tuning-report-G10.md).
"""

import os
import random
from datetime import datetime, timedelta

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUTPUT_FILE = os.path.join(OUTPUT_DIR, "benchmark_10k_queries.sql")

TOTAL_QUERIES = 10000

# Sample parameters pools
SPACE_CODES = [f"{b}-{f}0{r}" for b in ['A', 'B', 'C', 'D', 'E'] for f in range(1, 6) for r in range(1, 6)]
STATUSES = ['Pending', 'Approved', 'Rejected', 'Cancelled', 'CheckedIn', 'Completed', 'NoShow']
ROLES = ['Student', 'Lecturer', 'TeachingAssistant', 'FacilityStaff', 'DepartmentAdministrator']
PURPOSES = ['Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'StudentActivity']

# Query Templates
QUERY_TEMPLATES = [
    # 1. Booking Overlap Check (Hot path for booking validation)
    """SELECT BookingID, SpaceCode, StartTime, EndTime, Status
FROM BookingRequest WITH (NOLOCK)
WHERE SpaceCode = '{space}'
  AND Status IN ('Approved', 'CheckedIn')
  AND StartTime < '{end_time}'
  AND EndTime > '{start_time}';""",

    # 2. User Booking History Search (User dashboard)
    """SELECT BR.BookingID, BR.SpaceCode, BR.StartTime, BR.EndTime, BR.Status, S.SpaceName
FROM BookingRequest BR WITH (NOLOCK)
JOIN [Space] S ON BR.SpaceCode = S.SpaceCode
WHERE BR.RequesterID = {user_id}
  AND BR.StartTime >= '{start_time}'
ORDER BY BR.StartTime DESC;""",

    # 3. Active Maintenance Advisory Search
    """SELECT M.MaintenanceID, M.SpaceCode, M.ProblemDescription, M.ImpactLevel, M.StartTime, M.CompletionTime
FROM MaintenanceRecord M WITH (NOLOCK)
WHERE M.SpaceCode = '{space}'
  AND M.Status IN ('Open', 'InProgress')
  AND M.ImpactLevel = '{impact}';""",

    # 4. Department Utilization Analytical Query
    """SELECT U.Department, S.SpaceType, COUNT(BR.BookingID) AS TotalBookings, SUM(DATEDIFF(MINUTE, BR.StartTime, BR.EndTime)) AS TotalMinutes
FROM BookingRequest BR WITH (NOLOCK)
JOIN [User] U ON BR.RequesterID = U.UserID
JOIN [Space] S ON BR.SpaceCode = S.SpaceCode
WHERE BR.StartTime >= '{start_time}' AND BR.EndTime <= '{end_time}'
GROUP BY U.Department, S.SpaceType
ORDER BY TotalBookings DESC;""",

    # 5. Unacknowledged Advisory Bookings (Phase 2 constraint check)
    """SELECT BR.BookingID, BR.RequesterID, BR.SpaceCode, MR.MaintenanceID, MR.ProblemDescription
FROM BookingRequest BR WITH (NOLOCK)
JOIN MaintenanceRecord MR ON BR.SpaceCode = MR.SpaceCode
LEFT JOIN BookingAcknowledgement BA ON BR.BookingID = BA.BookingID AND MR.MaintenanceID = BA.MaintenanceID
WHERE MR.ImpactLevel = 'Advisory'
  AND BR.StartTime < ISNULL(MR.CompletionTime, '2099-12-31')
  AND BR.EndTime > MR.StartTime
  AND BA.BookingID IS NULL;"""
]

def generate_random_date_pair():
    base_date = datetime(2023, 9, 1) + timedelta(days=random.randint(0, 1000))
    start_time = base_date + timedelta(hours=random.randint(7, 18))
    end_time = start_time + timedelta(hours=random.randint(1, 4))
    return start_time.strftime('%Y-%m-%d %H:%M:%S'), end_time.strftime('%Y-%m-%d %H:%M:%S')

def generate_workload(count=TOTAL_QUERIES, output_filepath=DEFAULT_OUTPUT_FILE):
    print(f"Generating {count} parameterized benchmark SQL queries...")
    
    with open(output_filepath, "w", encoding="utf-8") as f:
        f.write(f"-- =====================================================================\n")
        f.write(f"-- 10,000 Parameterized Benchmark Test Queries Workload\n")
        f.write(f"-- Target Database: CampusSpaceManagement\n")
        f.write(f"-- Total Queries  : {count}\n")
        f.write(f"-- =====================================================================\n\n")
        f.write("USE CampusSpaceManagement;\nSET NOCOUNT ON;\nGO\n\n")
        
        for i in range(1, count + 1):
            template = random.choice(QUERY_TEMPLATES)
            space = random.choice(SPACE_CODES)
            user_id = random.randint(1, 3000)
            impact = random.choice(['Advisory', 'OutOfService'])
            s_time, e_time = generate_random_date_pair()
            
            sql = template.format(
                space=space,
                user_id=user_id,
                impact=impact,
                start_time=s_time,
                end_time=e_time
            )
            
            f.write(f"-- Query #{i}\n")
            f.write(sql + "\nGO\n\n")
            
    print("Workload generation complete successfully.")

if __name__ == "__main__":
    generate_workload()
