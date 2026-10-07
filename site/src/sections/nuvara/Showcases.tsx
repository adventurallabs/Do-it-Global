import { useMemo } from 'react'
import { DeviceStory, type StoryStep } from '../../components/DeviceStory'
import { ParentHomeScreen, ParentScheduleScreen, ParentProgressScreen, ParentFeesScreen, ParentMessagesScreen, AwaySheet, UpiSheet } from '../../screens/nuvara/ParentScreens'
import { TherapistTodayScreen, TherapistSessionScreen, TherapistWeekScreen, TherapistChildScreen } from '../../screens/nuvara/TherapistScreens'
import { AdminHomeScreen, AdminTimetableScreen, AssessmentScreen, AdminChildScreen, AdminFeesScreen, AdminRequestsScreen, AdminMessagesScreen } from '../../screens/nuvara/AdminScreens'
import { NV_LILAC, NV_ORANGE, NV_SKY } from './Story'

const ICON = '/brand/nuvara-icon.webp'
const GREEN = '#22C55E'
const AMBER = '#F59E0B'
const VIOLET = '#B79BFF'

export function FamiliesShowcase() {
  const steps = useMemo<StoryStep[]>(
    () => [
      {
        label: 'Home',
        title: 'The next session, big and clear.',
        text: 'When, where and with whom — with Confirm or Request another slot right there, and today’s sessions as they happen.',
        screen: <ParentHomeScreen />,
        float: { text: 'Next session', sub: 'Today · 11:15 AM · OT with Priya', color: NV_SKY, pos: 'tr' },
      },
      {
        label: 'Can’t make it?',
        title: 'Away? Tell the centre in two taps.',
        text: 'Pick a reason and add a line. The therapist sees it straight away, so there is no need to call.',
        screen: <ParentHomeScreen overlay={<AwaySheet />} />,
        transition: 'tab',
        float: { text: 'Away · Unwell', sub: 'Seen by Priya straight away', color: AMBER, pos: 'bl' },
      },
      {
        label: 'Schedule',
        title: 'The week, session by session.',
        text: 'Every session with its time and therapist — the ones attended with their rating and note, and a change of time on anything still to come.',
        screen: <ParentScheduleScreen />,
        float: { text: 'Request another slot', sub: 'This session, or every one at that time', color: VIOLET, pos: 'tl' },
      },
      {
        label: 'Progress',
        title: 'Progress you can actually see.',
        text: 'After every session the therapist rates it from 0 to 10 and writes a few words. The chart shows the journey since the first day.',
        screen: <ParentProgressScreen />,
        float: { text: '7.4 out of 10', sub: 'Doing well · up 1.0 lately', color: GREEN, pos: 'br' },
      },
      {
        label: 'Fees',
        title: 'A weekly bill for sessions attended.',
        text: 'Only attended sessions are charged, at the child’s own fee per session — laid out like an invoice, therapy by therapy.',
        screen: <ParentFeesScreen />,
        float: { text: '₹3,300 due', sub: 'Week of 28 Sep · 5 of 6 attended', color: NV_ORANGE, pos: 'tr' },
      },
      {
        label: 'Pay with UPI',
        title: 'Pay from any UPI app.',
        text: 'Straight to the centre’s UPI ID, with no gateway in between. The amount and reference are fixed by the centre, and the receipt downloads any time.',
        screen: <ParentFeesScreen overlay={<UpiSheet />} />,
        transition: 'tab',
        float: { text: 'No gateway fees', sub: 'Paid to nuvara@okaxis', color: GREEN, pos: 'bl' },
      },
      {
        label: 'Messages',
        title: 'A direct line to the centre.',
        text: 'One conversation per child, with read ticks and live updates. Families only ever talk with the centre — never with each other.',
        screen: <ParentMessagesScreen />,
        float: { text: 'Read', sub: 'Live updates · read ticks', color: NV_SKY, pos: 'tl' },
      },
    ],
    [],
  )
  return (
    <DeviceStory
      id="families"
      kind="phone"
      accent={NV_SKY}
      icon={ICON}
      name="Families"
      subtitle="Every session, close to home."
      audience="Nuvara for parents"
      lead="The next session, how it went and what is due — for every child in the family, switched with one tap."
      steps={steps}
      screenBg="#F5F6FB"
    />
  )
}

export function TherapistsShowcase() {
  const steps = useMemo<StoryStep[]>(
    () => [
      {
        label: 'Today',
        title: 'Live, next and done on one timeline.',
        text: 'Today’s sessions with the children in each. Attendance opens 15 minutes before the start and locks when the session ends.',
        screen: <TherapistTodayScreen />,
        float: { text: 'Live now', sub: 'Speech group · Room 1', color: GREEN, pos: 'tr' },
      },
      {
        label: 'Attendance',
        title: 'Present, late or absent — in one tap.',
        text: 'Or mark everyone present at once. A child whose parent sent an absence notice is flagged before the session starts.',
        screen: <TherapistTodayScreen aarav="present" anaya="present" />,
        transition: 'tab',
        float: { text: '2 of 4 marked', sub: 'Mark all present in one tap', color: GREEN, pos: 'bl' },
      },
      {
        label: 'Session report',
        title: 'A rating and a few words for home.',
        text: 'Rate each child from 0 to 10 and describe the session. It saves as you type and reaches the family’s Progress tab.',
        screen: <TherapistSessionScreen />,
        float: { text: '8/10 · Saved', sub: 'Shared with Aarav’s parents', color: NV_ORANGE, pos: 'tl' },
      },
      {
        label: 'My week',
        title: 'The whole week — and what’s left to do.',
        text: 'Sessions day by day, hours and children at a glance, with anything still to mark or report standing out.',
        screen: <TherapistWeekScreen />,
        float: { text: 'Report pending', sub: 'Monday · Speech · Room 1', color: AMBER, pos: 'br' },
      },
      {
        label: 'Children',
        title: 'Every child’s story in one place.',
        text: 'Parents a tap away, the assessment history and progress over time, and ratings from every therapist.',
        screen: <TherapistChildScreen />,
        float: { text: '72% at the expected level', sub: 'Up 24 points since July', color: GREEN, pos: 'tr' },
      },
    ],
    [],
  )
  return (
    <DeviceStory
      id="therapists"
      kind="phone"
      accent={NV_ORANGE}
      icon={ICON}
      name="Therapists"
      subtitle="The day, one session at a time."
      audience="Nuvara for therapists"
      lead="Who is coming, who is here and how it went — recorded between sessions, without the paperwork."
      steps={steps}
      screenBg="#F5F6FB"
    />
  )
}

export function CentreShowcase() {
  const steps = useMemo<StoryStep[]>(
    () => [
      {
        label: 'Home',
        title: 'Today, and what needs you.',
        text: 'Slots in session, attendance so far and a short list of what needs attention — each item opens right where it’s fixed.',
        screen: <AdminHomeScreen />,
        float: { text: 'Needs attention · 5', sub: 'Reports, payments, absences', color: NV_ORANGE, pos: 'tr' },
      },
      {
        label: 'Timetable',
        title: 'A week that can’t double-book.',
        text: 'Time slots by day, busier ones in deeper navy. No therapist or child can ever be in two sessions at once — the database refuses it.',
        screen: <AdminTimetableScreen />,
        float: { text: 'No double-booking', sub: 'Enforced by the database', color: GREEN, pos: 'bl' },
      },
      {
        label: 'OT assessment',
        title: 'The paper assessment, rebuilt.',
        text: 'The centre’s Pediatric OT form as 18 sections of one-tap answers, with follow-up questions only when they are needed.',
        screen: <AssessmentScreen />,
        float: { text: 'Saved as you go', sub: 'Even offline — sent when back', color: GREEN, pos: 'tl' },
      },
      {
        label: 'Children',
        title: 'Each child, fully on record.',
        text: 'Therapies with the child’s own fee per session, assessment progress over time, and the family a tap away.',
        screen: <AdminChildScreen />,
        float: { text: 'Own fee · ₹650', sub: 'Standard ₹700 per session', color: NV_SKY, pos: 'br' },
      },
      {
        label: 'Fees',
        title: 'Who owes what, week by week.',
        text: 'Outstanding by child and by week. Record cash or bank payments, verify UPI ones, and reverse anything that never arrived.',
        screen: <AdminFeesScreen />,
        float: { text: '₹10,900 outstanding', sub: '4 children to collect from', color: NV_ORANGE, pos: 'tr' },
      },
      {
        label: 'Slot requests',
        title: 'Families ask. The centre answers.',
        text: 'Requests to move one session or every session at that time — answered with a new slot, or turned down with a note.',
        screen: <AdminRequestsScreen />,
        float: { text: 'Needs your answer', sub: 'Before Friday’s session', color: VIOLET, pos: 'bl' },
      },
      {
        label: 'Messages',
        title: 'Every family and therapist, one inbox.',
        text: 'A chat with each child’s family and with each therapist, with unread counts and read ticks.',
        screen: <AdminMessagesScreen />,
        float: { text: '2 unread', sub: 'Families and therapists', color: NV_SKY, pos: 'tl' },
      },
    ],
    [],
  )
  return (
    <DeviceStory
      id="centre"
      kind="tablet"
      accent={NV_LILAC}
      icon={ICON}
      name="The centre"
      subtitle="Run the whole centre from one place."
      audience="Nuvara for centre admins"
      lead="Timetables, children, therapists, fees and assessments — on a phone, a tablet or a laptop."
      steps={steps}
      screenBg="#F5F6FB"
    />
  )
}
