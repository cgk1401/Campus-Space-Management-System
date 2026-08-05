# Project Campus Space Management System

## 1. Business requirement description 

**1.1. System Overview**
- The School wants to develop a system to manage the booking and usage of shared campus spaces such as:
    - Classrooms
    - Computer laboratories
    - Meeting rooms
    - Auditoriums

**1.2. User Management**
- Each user must have a university account. The system stores basic user information, including:
    - User ID
    - Full name
    - Email
    - Phone number
    - Role
    - Department
    - Account status
- A user role may be:
    - Student
    - Lecturer
    - Teaching assistant
    - Facility staff
    - Department administrator
    - Facility manager

**1.3. Space & Facility Management**
- For each space, the system stores: 
    - Space code (unique)
    - Space name
    - Space type
    - Building
    - Floor
    - Room number
    - Capacity
    - Current status
    - Usage policy
- A space status may be:
    - Available
    - In use
    - Under maintenance
    - Temporarily closed
    - Retired
- Each space may have a list of facilities, such as:
    - Projector
    - Whiteboard
    - Microphone
    - Computer
    - Livestreaming equipment
    - Air conditioner
- Facility is modeled as individual physical units, not types. Each unit has its own FacilityID surrogate key, a FacilityName indicating type, 
  and belongs to exactly one Space (1:N). This allows individual units to be referenced in maintenance records.

**1.4. Booking Request Management**
- Users can submit booking requests containing:
    - Selected space
    - Requested start time & end time
    - Purpose of use
    - Expected number of participants
- Purpose of use includes:
    - Lecture, Examination, Seminar, Workshop, Meeting, Student activity, Administrative event.
- Booking status includes:
    - Pending, Approved, Rejected, Cancelled, Checked in, Completed, No-show.
- **Booking Constraints (System Rules):**
    - Prevent conflicting/overlapping bookings for the same space.
    - Spaces that are *Under maintenance*, *Temporarily closed*, or *Retired* CANNOT be booked.

**1.5. Approval Process**
- Bookings may require approval from a facility staff member or manager.
- System must record:
    - Approver (staff member who made the decision)
    - Decision time
    - Decision note
    - Rejection reason (if rejected)

**1.6. Usage Session (Check-in & Check-out)**
- **Check-in (Arrival):** Records actual start time, staff who checked in, and initial condition of the space.
- **Completion (End):** Records actual end time, final condition of the space, and usage notes.
- UsageSession must link to both BookingRequest (via BookingID as PK and FK, 
  preserving the 1:1 relationship) and to Approval (via ApprovalID as an additional FK). This ensures a UsageSession can only exist if a valid 
  Approval exists for the booking, while still maintaining direct traceability to the original booking request.

**1.7. Maintenance Management**
- System tracks maintenance records for issues like broken equipment, damaged furniture, or network problems.
- Each maintenance record stores:
    - Related space
    - Reporter
    - Assigned staff member
    - Problem description
    - Start time & Completion time
    - Status
    - Result note
- **Constraint:** A space under maintenance CANNOT be booked.

**1.8. Reporting & History**
- The system must keep historical records of bookings and maintenance.
- Staff can view:
    - Booking history
    - Upcoming bookings
    - Spaces under maintenance
    - No-show bookings

**1.9. Main System Goals**
- Manage shared spaces fairly.
- Avoid overlapping bookings.
- Prevent the use of unavailable spaces.
- Preserve usage history.

Hiểu rồi! Bạn muốn bám sát chính xác cấu trúc là **"2. Phase 1"** và bổ sung thêm bước số 1 (Business Requirement Analysis) mà lúc nãy chưa có. 

Dưới đây là bản tóm tắt và định dạng lại cực kỳ chuẩn xác, sạch sẽ theo đúng format gạch đầu dòng để bạn ghép nối tiếp vào phần 1 ở trên:

***

## 2. Phase 1 (Project Tasks)

**2.1. Business Requirement Analysis**
- Analyze the business requirements to identify:
    - Business purpose
    - Actors (Users)
    - Entities & Attributes
    - Relationships & Cardinalities
    - Business rules

**2.2. Conceptual Database Design**
- Design an Entity-Relationship Diagram (ERD).
- The ERD must show: 
    - Main entities & attributes
    - Relationships
    - Cardinalities (e.g., 1:1, 1:N, M:N)
    - Participation constraints (mandatory/optional)

**2.3. Logical Database Design**
- Convert the ERD into a Relational Schema.
- The schema must define:
    - Relations (tables) & attributes
    - Primary Keys (PK) & Foreign Keys (FK)
    - Candidate keys
    - Key constraints

**2.4. Database Design Validation**
- Evaluate the relational schema to ensure it:
    - Correctly represents the ERD.
    - Satisfies all business rules.
    - Uses appropriate keys, relationships, and constraints.

**2.5. Database Implementation**
- Implement the database using SQL DDL (Data Definition Language).
- The SQL script must include:
    - Tables
    - Keys (PK, FK)
    - Constraints & `CHECK` conditions
    - `DEFAULT` values where appropriate

**2.6. Sample Data Preparation**
- Insert realistic sample data using SQL DML.
- Data must support testing of:
    - Normal operations (standard workflow).
    - Important exceptional cases (e.g., conflicting bookings, invalid data).

**2.7. Query Design**
- **Requirement:** Each student must design and execute **at least 5 meaningful SQL queries**.
- Queries must be valid for the database and useful for answering real business questions.
- **For EACH query, the following details must be included:**
    - **Business question:** What information is needed?
    - **Target user(s):** Who would use this query? (e.g., Facility Manager)
    - **Short explanation:** Why is this query useful for the business?
    - **SQL statement:** The actual SQL code.