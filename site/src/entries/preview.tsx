// Dev-only contact sheet of every recreated screen. Not part of the build.
import { createRoot } from 'react-dom/client'
import '@fontsource-variable/geist'
import '@fontsource-variable/outfit'
import '@fontsource-variable/fraunces'
import '@fontsource-variable/roboto'
import '../styles/global.css'
import '../styles/screens.css'
import { DeviceFrame } from '../components/DeviceFrame'
import { TodayScreen, HomeworkScreen, DiaryScreen } from '../screens/connect/TodayScreens'
import { ResultsScreen, TimetableScreen, MessagesScreen, DigitalIdScreen, NotificationsScreen } from '../screens/connect/SchoolScreens'
import { ProgressScreen, AttendanceScreen, FeesScreen, BusScreen } from '../screens/connect/FeatureScreens'
import { AdminDashboardScreen, TeacherHomeScreen, ClassroomScreen } from '../screens/core/HomeScreens'
import { RollCallScreen, TimetableAdminScreen, AnnouncementsScreen, EventsScreen, FeeManagementScreen, BusFleetScreen } from '../screens/core/OpsScreens'

const phones = [<TodayScreen />, <TodayScreen lang="ta" />, <HomeworkScreen />, <DiaryScreen />, <ResultsScreen />, <TimetableScreen />, <MessagesScreen />, <DigitalIdScreen />, <NotificationsScreen />, <ProgressScreen />, <AttendanceScreen />, <FeesScreen />, <BusScreen />, <TeacherHomeScreen />, <AdminDashboardScreen />]
const tablets = [<AdminDashboardScreen />, <TeacherHomeScreen />, <ClassroomScreen />, <RollCallScreen />, <TimetableAdminScreen />, <AnnouncementsScreen />, <EventsScreen />, <FeeManagementScreen />, <BusFleetScreen />]
const which = new URLSearchParams(location.search).get('k') ?? 'phone'

createRoot(document.getElementById('root')!).render(
  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 24, padding: 24 }}>
    {(which === 'phone' ? phones : tablets).map((s, i) => (
      <DeviceFrame key={i} kind={which === 'phone' ? 'phone' : 'tablet'} style={which === 'phone' ? { width: 300, height: 640 } : { width: 900, height: 640 }}>
        {s}
      </DeviceFrame>
    ))}
  </div>,
)
