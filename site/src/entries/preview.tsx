// Dev-only contact sheet of every recreated screen. Not part of the build.
import type { ReactElement } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource-variable/geist'
import '@fontsource-variable/outfit'
import '@fontsource-variable/fraunces'
import '@fontsource-variable/roboto'
import '@fontsource-variable/archivo'
import '@fontsource-variable/plus-jakarta-sans'
import '../styles/global.css'
import '../styles/screens.css'
import { DeviceFrame } from '../components/DeviceFrame'
import { TodayScreen, HomeworkScreen, DiaryScreen } from '../screens/connect/TodayScreens'
import { ResultsScreen, TimetableScreen, MessagesScreen, DigitalIdScreen, NotificationsScreen } from '../screens/connect/SchoolScreens'
import { ProgressScreen, AttendanceScreen, FeesScreen, BusScreen } from '../screens/connect/FeatureScreens'
import { AdminDashboardScreen, TeacherHomeScreen, ClassroomScreen } from '../screens/core/HomeScreens'
import { RollCallScreen, TimetableAdminScreen, AnnouncementsScreen, EventsScreen, FeeManagementScreen, BusFleetScreen } from '../screens/core/OpsScreens'
import { ParentHomeScreen, ParentScheduleScreen, ParentProgressScreen, ParentFeesScreen, ParentMessagesScreen, UpiSheet, AwaySheet } from '../screens/nuvara/ParentScreens'
import { TherapistTodayScreen, TherapistSessionScreen, TherapistWeekScreen, TherapistChildScreen } from '../screens/nuvara/TherapistScreens'
import { AdminHomeScreen, AdminTimetableScreen, AdminChildScreen, AdminFeesScreen, AdminRequestsScreen, AdminMessagesScreen, AssessmentScreen } from '../screens/nuvara/AdminScreens'

const phones = [<TodayScreen />, <TodayScreen lang="ta" />, <HomeworkScreen />, <DiaryScreen />, <ResultsScreen />, <TimetableScreen />, <MessagesScreen />, <DigitalIdScreen />, <NotificationsScreen />, <ProgressScreen />, <AttendanceScreen />, <FeesScreen />, <BusScreen />, <TeacherHomeScreen />, <AdminDashboardScreen />]
const tablets = [<AdminDashboardScreen />, <TeacherHomeScreen />, <ClassroomScreen />, <RollCallScreen />, <TimetableAdminScreen />, <AnnouncementsScreen />, <EventsScreen />, <FeeManagementScreen />, <BusFleetScreen />]
const nvPhones = [<ParentHomeScreen />, <ParentHomeScreen confirmed attended rated scroll={430} />, <ParentScheduleScreen />, <ParentProgressScreen />, <ParentFeesScreen />, <ParentFeesScreen paid />, <ParentFeesScreen overlay={<UpiSheet />} />, <ParentHomeScreen overlay={<AwaySheet />} />, <ParentMessagesScreen />, <TherapistTodayScreen />, <TherapistTodayScreen aarav="present" />, <TherapistSessionScreen />, <TherapistWeekScreen />, <TherapistChildScreen />, <AdminHomeScreen />, <AdminFeesScreen />, <AssessmentScreen />]
const nvTablets = [<AdminHomeScreen />, <AdminTimetableScreen />, <AdminChildScreen />, <AdminFeesScreen />, <AdminRequestsScreen />, <AdminMessagesScreen />, <AssessmentScreen />, <AssessmentScreen answered={6} />]
const which = new URLSearchParams(location.search).get('k') ?? 'phone'
const sets: Record<string, [ReactElement[], 'phone' | 'tablet']> = { phone: [phones, 'phone'], tablet: [tablets, 'tablet'], 'nv-phone': [nvPhones, 'phone'], 'nv-tablet': [nvTablets, 'tablet'] }
const [list, kind] = sets[which] ?? sets.phone

createRoot(document.getElementById('root')!).render(
  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 24, padding: 24 }}>
    {list.map((s, i) => (
      <DeviceFrame key={i} kind={kind} style={kind === 'phone' ? { width: 300, height: 640 } : { width: 900, height: 640 }}>
        {s}
      </DeviceFrame>
    ))}
  </div>,
)
