import { useMemo } from 'react'
import { DeviceStory, type StoryStep } from '../../components/DeviceStory'
import { TodayScreen, HomeworkScreen, DiaryScreen } from '../../screens/connect/TodayScreens'
import { ResultsScreen, TimetableScreen, MessagesScreen, DigitalIdScreen } from '../../screens/connect/SchoolScreens'
import { AdminDashboardScreen, TeacherHomeScreen, ClassroomScreen } from '../../screens/core/HomeScreens'
import { RollCallScreen, TimetableAdminScreen, AnnouncementsScreen, EventsScreen, FeeManagementScreen, BusFleetScreen } from '../../screens/core/OpsScreens'

const SKY = '#3EC6FF'
const GOLD = '#E2C275'

export function ConnectShowcase() {
  const steps = useMemo<StoryStep[]>(
    () => [
      {
        label: 'Today',
        title: 'The whole school day, at a glance.',
        text: 'Today’s classes, homework that’s due, what your child learned and what the teacher noticed — the first screen parents open each morning.',
        screen: <TodayScreen />,
        float: { text: 'Science · Now', sub: '10:30 – 11:10 AM · Ms. Kavya', color: SKY, pos: 'tr' },
      },
      {
        label: 'Multilingual',
        title: 'English and தமிழ், on every screen.',
        text: 'The app is written for families in both languages. Choose once and every screen follows.',
        screen: <TodayScreen lang="ta" />,
        transition: 'tab',
        float: { text: 'தமிழ்', sub: 'Language', color: SKY, pos: 'bl' },
      },
      {
        label: 'Homework',
        title: 'Homework that never gets lost in a bag.',
        text: 'See what is due today, tomorrow or overdue. Mark it done at home, and see when the teacher is reviewing it.',
        screen: <HomeworkScreen />,
        float: { text: 'Due today', sub: 'Mathematics — worksheet 4', color: '#F59E0B', pos: 'tl' },
      },
      {
        label: 'Diary',
        title: 'The class diary, written by the school.',
        text: 'Homework, teacher notes, school notices and activities — organised by day and searchable.',
        screen: <DiaryScreen />,
        transition: 'tab',
        float: { text: 'Parent meeting', sub: 'Saturday, 10:00 AM · Main hall', color: GOLD, pos: 'br' },
      },
      {
        label: 'Exams & results',
        title: 'Results the moment they’re published.',
        text: 'Exam timetables with the syllabus for each subject, then a clear statement of marks as results are released.',
        screen: <ResultsScreen />,
        float: { text: 'All results are out', sub: 'Quarterly exams', color: '#22C55E', pos: 'tr' },
      },
      {
        label: 'School life',
        title: 'Know exactly where the day is.',
        text: 'The class timetable with the period happening now, what comes next, and covers when a teacher is away.',
        screen: <TimetableScreen />,
        float: { text: 'Cover', sub: 'Social Science · 12:30', color: '#F59E0B', pos: 'bl' },
      },
      {
        label: 'Messages',
        title: 'A direct line to the class teacher.',
        text: 'Message the teacher, request leave or let the school know your child is running late — with a document when it’s needed.',
        screen: <MessagesScreen />,
        float: { text: 'Request Leave', sub: 'Under Review', color: '#2F6BFF', pos: 'tl' },
      },
      {
        label: 'Digital ID',
        title: 'A student ID that lives on the phone.',
        text: 'A verified digital identity card with admission details and a verification code.',
        screen: <DigitalIdScreen />,
        float: { text: 'Verified Student', color: '#22C55E', pos: 'br' },
      },
    ],
    [],
  )
  return (
    <DeviceStory
      id="connect"
      kind="phone"
      accent={SKY}
      icon="/brand/palliconnect-icon.webp"
      name="PalliConnect"
      subtitle="The parent & student experience."
      audience="Parents & students"
      lead="Everything a family needs to stay close to school life — the day, the homework, the progress and the bus — in one calm app."
      steps={steps}
      screenBg="#F7FBFF"
    />
  )
}

export function CoreShowcase() {
  const steps = useMemo<StoryStep[]>(
    () => [
      {
        label: 'Admin dashboard',
        title: 'The whole school, at a glance.',
        text: 'Students, staff present, attendance and pending fees — and what needs attention today — on the first screen.',
        screen: <AdminDashboardScreen />,
        float: { text: '2 classes not marked yet', sub: 'Attendance · today', color: '#F59E0B', pos: 'tr' },
      },
      {
        label: 'Teacher dashboard',
        title: 'A teacher’s day, period by period.',
        text: 'Today’s schedule with what is on now, what’s been taken and what’s next. Start class and roll call in one tap.',
        screen: <TeacherHomeScreen />,
        float: { text: 'Start class & roll call', sub: 'Period 3 · Class 5-A', color: GOLD, pos: 'bl' },
      },
      {
        label: 'Classroom tools',
        title: 'Everything the class teacher needs.',
        text: 'Attendance, marks, stars and progress, the diary and today’s update — shared with parents in a tap.',
        screen: <ClassroomScreen />,
        float: { text: 'Share with parents', sub: 'Lands on their Today screen', color: GOLD, pos: 'tl' },
      },
      {
        label: 'Attendance',
        title: 'Roll call in seconds.',
        text: 'Present, absent or leave for the whole class. Search by name, roll or register number, then save.',
        screen: <RollCallScreen />,
        transition: 'tab',
        float: { text: 'Attendance saved', color: '#3E8E5E', pos: 'br' },
      },
      {
        label: 'Timetable',
        title: 'Timetables that catch clashes.',
        text: 'Compose each classroom’s weekly schedule. Overlapping periods are flagged before they reach a classroom.',
        screen: <TimetableAdminScreen />,
        float: { text: 'Fix overlapping periods', sub: 'Mr. Arun · 9:40', color: '#F59E0B', pos: 'tr' },
      },
      {
        label: 'Announcements',
        title: 'One notice. The right audience.',
        text: 'Post school-wide, to staff or to a single class — and mark what matters as important.',
        screen: <AnnouncementsScreen />,
        float: { text: 'Mark as important', sub: 'Highlighted at the top for readers', color: GOLD, pos: 'bl' },
      },
      {
        label: 'Events',
        title: 'From the first notice to the certificate.',
        text: 'Compose an event, assign category heads, notify families and publish certificates when it’s done.',
        screen: <EventsScreen />,
        float: { text: 'Certificates published', color: '#3E8E5E', pos: 'tl' },
      },
      {
        label: 'Fees',
        title: 'Fee management without the spreadsheet.',
        text: 'Collected and pending, class by class — and every payment recorded against the student.',
        screen: <FeeManagementScreen />,
        float: { text: 'Record payment', sub: 'Online · Class 5-A', color: '#6FA3A0', pos: 'br' },
      },
      {
        label: 'Buses',
        title: 'The whole fleet, live.',
        text: 'Every bus with its route, driver and live trip status, in one place.',
        screen: <BusFleetScreen />,
        float: { text: 'Bus 07 · LIVE', sub: 'Near Gandhi Nagar', color: '#3E8E5E', pos: 'tr' },
      },
    ],
    [],
  )
  return (
    <DeviceStory
      id="core"
      kind="tablet"
      accent={GOLD}
      icon="/brand/pallicore-icon.webp"
      name="PalliCore"
      subtitle="The operating system for the school."
      audience="Administrators · Teachers · Operations"
      lead="Built for the people who run the school — administrators who see the whole campus, and teachers who run the classroom."
      steps={steps}
      screenBg="#EDEBE7"
    />
  )
}
