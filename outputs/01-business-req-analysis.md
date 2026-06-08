# 01 — Business Requirement Analysis

## 1. Business Purpose

The School of Computer Science manages several shared physical spaces (auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, student workspaces) used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. The current manual process (email, phone, spreadsheets, shared calendars) has become unmanageable as demand grows. The School requires a database system to automate and manage space booking, approval workflows, usage session tracking, maintenance management, incident reporting, and facility utilization.

**Primary goals:**
- Manage shared campus spaces fairly.
- Avoid overlapping bookings.
- Prevent the use of unavailable spaces.
- Preserve full usage and maintenance history.

---

## 2. Actors (Users & Roles)

| Role | Description |
|------|-------------|
| Student | Submits booking requests for student activities or projects. |
| Lecturer | Submits booking requests for lectures, seminars, workshops, examinations. |
| Teaching Assistant | May book spaces on behalf of a course or lecturer. |
| Facility Staff | Checks in/out bookings, approves/rejects requests, handles maintenance tasks. |
| Department Administrator | May oversee bookings and usage within the department. |
| Facility Manager | High-level oversight; approves/rejects bookings, manages maintenance. |

---

## 3. Entities & Attributes

### 3.1. User
Stores all individuals who interact with the system.

| Attribute | Type | Notes |
|-----------|------|-------|
| User ID | PK | University account identifier |
| Full name | String | |
| Email | String | |
| Phone number | String | |
| Role | Enum | Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager |
| Department | String | |
| Account status | Enum | e.g., Active, Inactive, Suspended |

### 3.2. Space
Represents a bookable physical location.

| Attribute | Type | Notes |
|-----------|------|-------|
| Space code | PK | Unique identifier |
| Space name | String | |
| Space type | Enum | e.g., Auditorium, Classroom, Computer Lab, Project Lab, Meeting Room, Student Workspace |
| Building | String | |
| Floor | Integer | |
| Room number | String | |
| Capacity | Integer | |
| Current status | Enum | Available, In Use, Under Maintenance, Temporarily Closed, Retired |
| Usage policy | Text | Rules/guidelines for using the space |

### 3.3. Facility
Equipment or amenity available within a space.

| Attribute | Type | Notes |
|-----------|------|-------|
| Facility ID | PK | |
| Facility name | String | e.g., Projector, Whiteboard, Microphone, Computer, Livestreaming Equipment, Air Conditioner |
| (Space code) | FK | The space this facility belongs to |

### 3.4. Booking Request
A request submitted by a user to reserve a space.

| Attribute | Type | Notes |
|-----------|------|-------|
| Booking ID | PK | |
| (Requester ID) | FK | References User |
| (Space code) | FK | References Space |
| Requested start time | DateTime | |
| Requested end time | DateTime | |
| Purpose of use | Enum | Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event |
| Expected participants | Integer | |
| Status | Enum | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-show |

### 3.5. Approval
Records the decision on a booking request.

| Attribute | Type | Notes |
|-----------|------|-------|
| Approval ID | PK | |
| (Booking ID) | FK | References Booking Request (1:1) |
| (Approver ID) | FK | References User (Facility Staff or Manager) |
| Decision time | DateTime | |
| Decision note | String | |
| Rejection reason | String | Required only if status is Rejected |

### 3.6. Usage Session
Captures check-in and check-out details for a booking.

| Attribute | Type | Notes |
|-----------|------|-------|
| (Booking ID) | PK, FK | References Booking Request (1:1) |
| Actual start time | DateTime | Logged at check-in |
| Check-in staff ID | FK | References User |
| Initial condition | Text | Condition of space upon arrival |
| Actual end time | DateTime | Logged at completion |
| Final condition | Text | Condition of space after use |
| Usage notes | Text | Any notes from staff |

### 3.7. Maintenance Record
Tracks reported issues and repair work for spaces.

| Attribute | Type | Notes |
|-----------|------|-------|
| Maintenance ID | PK | |
| (Space code) | FK | References Space |
| (Reporter ID) | FK | References User (who reported) |
| (Assigned staff ID) | FK | References User (Facility Staff assigned) |
| Problem description | Text | |
| Start time | DateTime | |
| Completion time | DateTime | Nullable; set when resolved |
| Status | Enum | e.g., Reported, In Progress, Completed, Cancelled |
| Result note | Text | Summary of resolution |

---

## 4. Relationships & Cardinalities

| Entity A | Relationship | Entity B | Cardinality | Participation |
|----------|-------------|----------|-------------|---------------|
| User | submits | Booking Request | 1:N | User: optional (a user may have 0 bookings); Booking: mandatory |
| Space | is booked by | Booking Request | 1:N | Space: optional; Booking: mandatory |
| Booking Request | has | Approval | 1:1 | Booking: optional (may remain pending); Approval: mandatory if decision made |
| User | approves | Approval | 1:N | User: optional; Approval: mandatory |
| Space | contains | Facility | 1:N | Space: optional (may have 0 facilities); Facility: mandatory |
| Space | has | Maintenance Record | 1:N | Space: optional; Maintenance: mandatory |
| User | reports | Maintenance Record | 1:N | User: optional; Maintenance: mandatory |
| User | is assigned to | Maintenance Record | 1:N | User: optional; Maintenance: optional (may be unassigned) |
| Booking Request | has | Usage Session | 1:1 | Booking: optional (not yet checked in); Usage Session: mandatory if checked in |

---

## 5. Business Rules

1. **Unique booking identification** — Each booking request has a unique Booking ID.
2. **Conflict prevention** — The same space cannot have two approved bookings with overlapping time periods. The system must enforce this constraint.
3. **Unavailable space restriction** — Spaces with status *Under Maintenance*, *Temporarily Closed*, or *Retired* cannot be booked.
4. **Approval tracking** — When a booking is approved or rejected, the system must record the approving staff member, decision time, decision note, and (if rejected) the rejection reason.
5. **Check-in / Check-out** — Actual start/end times and space conditions must be recorded during check-in and check-out.
6. **Maintenance blocks booking** — A space with an active (non-completed) maintenance record cannot be booked.
7. **Historical records** — Past bookings and maintenance records must be preserved and queryable (no physical deletion).
8. **University account** — Every user must have a university account to interact with the system.
9. **Status lifecycle** — Booking status transitions follow: Pending → (Approved | Rejected | Cancelled) → Checked In → Completed | No-show.

---

## 6. Assumptions

- A booking request cannot have more than one approval decision; once decided, the decision is final (no re-approval).
- The system does **not** handle room scheduling algorithms (e.g., auto-assignment) — it only records and validates requests.
- Check-in and Check-out are separate operations performed by facility staff, not the requester.
- A maintenance record is considered "active" (blocking bookings) when its status is *Reported* or *In Progress*.
- A space may have zero facilities; facilities are tracked only as names (no inventory tracking).
- The `Usage Policy` attribute on Space stores free-text rules (e.g., "No food allowed", "Max 2-hour booking").

---

## 7. Open Questions

1. Should the system support recurring booking requests (e.g., weekly lectures for a full semester)?
2. Should there be a maximum booking duration per user or per space?
3. How are "no-show" bookings determined — automatically after a grace period, or manually by staff?
4. Should facility staff be able to override overlapping-booking constraints in emergencies?
5. Is there a hierarchy of approvers (e.g., large events require manager approval while small events can be approved by any staff)?
