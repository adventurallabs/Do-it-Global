import { RevealText } from '../../components/RevealText'
import { Reveal } from '../../components/Reveal'
import { SectionLabel } from '../../components/Primitives'
import { MagneticButton, Arrow } from '../../components/MagneticButton'
import { DigMark } from '../../components/Nav'
import { useSection } from '../../hooks/useSection'
import { VISION } from '../../data/company'
import { SITE } from '../../data/site'

export function Vision() {
  const ref = useSection<HTMLElement>('vision')
  return (
    <div ref={ref}>
      <section id="vision" className="relative flex min-h-[130svh] items-center">
        <div className="mx-auto w-full max-w-[1600px] px-5 text-center sm:px-8 md:px-12">
          <SectionLabel index="05" className="justify-center">
            {VISION.label}
          </SectionLabel>
          <RevealText text={VISION.statement} className="t-h1 mx-auto mt-10 max-w-[18ch] text-bone" stagger={0.04} />
          <Reveal className="mx-auto mt-10 max-w-[34rem]">
            <p className="t-lead">{VISION.sub}</p>
          </Reveal>
        </div>
      </section>
      <Footer />
    </div>
  )
}

function Footer() {
  return (
    <footer id="contact" className="relative bg-[linear-gradient(to_bottom,rgb(8_9_12/0)_0%,rgb(8_9_12/0.88)_28%,rgb(8_9_12/0.96)_100%)]">
      <div className="mx-auto max-w-[1600px] px-5 pb-10 pt-24 sm:px-8 md:px-12 md:pt-32">
        <div className="grid gap-16 md:grid-cols-12">
          <div className="md:col-span-7">
            <p className="t-label">Contact</p>
            <RevealText text={"Let’s build\nwhat’s next."} className="t-h1 mt-6 text-bone" />
            <div className="mt-10 flex flex-wrap gap-3">
              <MagneticButton href={`mailto:${SITE.email}`}>
                {SITE.email}
                <Arrow />
              </MagneticButton>
              <MagneticButton href={SITE.palliPath} target="_blank" rel="noopener" variant="ghost">
                Explore Palli
                <Arrow diagonal />
              </MagneticButton>
              <MagneticButton href={SITE.nuvaraPath} target="_blank" rel="noopener" variant="ghost">
                Explore Nuvara
                <Arrow diagonal />
              </MagneticButton>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-10 text-[0.92rem] md:col-span-5 md:grid-cols-3">
            <FooterCol title="Company">
              <a href="#build">What we build</a>
              <a href="#philosophy">How we build</a>
              <a href="#vision">Vision</a>
            </FooterCol>
            <FooterCol title="Products">
              <a href={SITE.palliPath} target="_blank" rel="noopener">
                Palli ↗
              </a>
              <a href={`${SITE.palliPath}#connect`} target="_blank" rel="noopener">
                PalliConnect
              </a>
              <a href={`${SITE.palliPath}#core`} target="_blank" rel="noopener">
                PalliCore
              </a>
              <a href={SITE.nuvaraPath} target="_blank" rel="noopener">
                Nuvara ↗
              </a>
            </FooterCol>
            <FooterCol title="Elsewhere">
              {SITE.social.map((s) => (
                <a key={s.label} href={s.href}>
                  {s.label}
                </a>
              ))}
            </FooterCol>
          </div>
        </div>

        <div className="mt-24 flex flex-col gap-6 border-t border-line pt-8 md:flex-row md:items-center md:justify-between">
          <div className="flex items-center gap-3 text-bone">
            <DigMark className="h-7 w-7" />
            <span className="text-[0.95rem] font-medium tracking-[-0.01em]">{SITE.company}</span>
          </div>
          <p className="text-[0.8rem] text-mute">
            © {SITE.year} {SITE.company}. Palli, PalliConnect, PalliCore and Nuvara are products of {SITE.shortName}.
          </p>
        </div>
      </div>
    </footer>
  )
}

function FooterCol({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="t-label mb-5">{title}</p>
      <div className="flex flex-col gap-3 text-bone/75 [&_a:hover]:text-bone [&_a]:transition-colors">{children}</div>
    </div>
  )
}
