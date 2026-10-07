import { mdiBadgeAccountOutline, mdiEyeOutline, mdiInformationOutline, mdiLockOutline } from '@mdi/js'
import { Icon } from '../../components/Primitives'
import type { Centre } from '../../data/nuvaraCentres'
import { Btn, Hero, NV, Segmented, StatusBar, b, d } from './kit'

/**
 * The phone sign-in screen (lib/screens/login.dart) as a centre's own app:
 * the centre's name where the wordmark sits, then the role picker and the
 * child's ID + password form.
 */
export function CentreSignInScreen({ centre }: { centre: Centre }) {
  return (
    <div className="nv absolute inset-0 overflow-hidden" style={{ background: NV.canvas }}>
      <StatusBar />
      <div className="absolute inset-x-0 bottom-0 top-[50px] px-[22px] pt-6">
        <Hero pad="22px 20px">
          <span className="block" style={{ ...d(27, 900, '#fff', 1.08), fontWeight: 900, letterSpacing: -0.8 }}>
            {centre.name}
          </span>
          <span className="mt-[18px] block" style={d(23, 500, '#fff', 1.15)}>
            Every step forward <span style={{ color: NV.sky }}>matters</span>
          </span>
        </Hero>
        <span className="mt-7 block" style={d(32)}>
          Welcome back
        </span>
        <span className="mt-1.5 block" style={b(14.5, 400, NV.muted)}>
          Who is signing in?
        </span>
        <div className="mt-4">
          <Segmented expand value={0} options={[{ label: 'Parent' }, { label: 'Therapist' }, { label: 'Admin' }]} />
        </div>
        <Field label="Child’s ID" icon={mdiBadgeAccountOutline} value="C001" />
        <Field label="Password" icon={mdiLockOutline} value="••••••••" trailing={mdiEyeOutline} />
        <div className="mt-2.5 flex gap-1.5">
          <Icon path={mdiInformationOutline} size={16} color={NV.brand600} className="mt-px shrink-0" />
          <span style={b(12.5, 400, NV.muted, 1.4)}>First time? Use your child&rsquo;s ID and the password from the centre, then set your own.</span>
        </div>
        <Btn className="mt-5" h={52}>
          Sign in
        </Btn>
        <span className="mt-3.5 block text-center" style={b(12.5, 400, NV.muted)}>
          Forgot your password? Ask the centre to reset it.
        </span>
      </div>
    </div>
  )
}

function Field({ label, icon, value, trailing }: { label: string; icon: string; value: string; trailing?: string }) {
  return (
    <div className="mt-4">
      <span className="block" style={b(12.5, 700)}>
        {label}
      </span>
      <div className="mt-[7px] flex h-[50px] items-center gap-3 rounded-[14px] bg-white px-3.5" style={{ border: '1px solid #8F94AD' }}>
        <Icon path={icon} size={19} color={NV.muted} />
        <span className="flex-1" style={b(15)}>
          {value}
        </span>
        {trailing && <Icon path={trailing} size={19} color={NV.muted} />}
      </div>
    </div>
  )
}
