import React, { forwardRef, useEffect, useState } from 'react';
import { Form } from 'formik';
import styled, { keyframes } from 'styled-components/macro';
import { breakpoint } from '@/theme';
import FlashMessageRender from '@/components/FlashMessageRender';
import tw from 'twin.macro';

const floatUp = keyframes`
    0%   { transform: translateY(100vh) scale(0); opacity: 0; }
    10%  { opacity: 1; }
    90%  { opacity: 0.6; }
    100% { transform: translateY(-10vh) scale(1); opacity: 0; }
`;

const fadeIn = keyframes`
    from { opacity: 0; transform: translateY(-20px); }
    to   { opacity: 1; transform: translateY(0); }
`;

const popIn = keyframes`
    0%   { opacity: 0; transform: scale(0.85) translateY(20px); }
    100% { opacity: 1; transform: scale(1) translateY(0); }
`;

const shimmer = keyframes`
    0%   { background-position: -200% center; }
    100% { background-position: 200% center; }
`;

const pulseGlow = keyframes`
    0%, 100% { box-shadow: 0 0 20px rgba(var(--xcasper-primary-rgb, 0,212,255),0.3), 0 0 40px rgba(var(--xcasper-accent-rgb, 124,58,237),0.15); }
    50%       { box-shadow: 0 0 40px rgba(var(--xcasper-primary-rgb, 0,212,255),0.5), 0 0 80px rgba(var(--xcasper-accent-rgb, 124,58,237),0.3); }
`;

const PageBackground = styled.div`
    position: fixed;
    inset: 0;
    background: transparent;
    overflow: hidden;
    z-index: 0;
`;

const Particle = styled.div<{ size: number; left: number; delay: number; duration: number }>`
    position: absolute;
    bottom: -10px;
    left: ${p => p.left}%;
    width: ${p => p.size}px;
    height: ${p => p.size}px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(var(--xcasper-primary-rgb, 0,212,255),0.8) 0%, rgba(var(--xcasper-accent-rgb, 124,58,237),0.4) 100%);
    animation: ${floatUp} ${p => p.duration}s linear ${p => p.delay}s infinite;
    filter: blur(${p => p.size < 5 ? 1 : 2}px);
`;

const GridOverlay = styled.div`
    position: absolute;
    inset: 0;
    background-image:
        linear-gradient(rgba(var(--xcasper-primary-rgb, 0,212,255),0.04) 1px, transparent 1px),
        linear-gradient(90deg, rgba(var(--xcasper-primary-rgb, 0,212,255),0.04) 1px, transparent 1px);
    background-size: 50px 50px;
`;

const PageWrapper = styled.div`
    position: relative;
    z-index: 1;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 24px 16px 80px;
`;

const LogoArea = styled.div`
    animation: ${fadeIn} 0.7s ease both;
    margin-bottom: 24px;
    text-align: center;
`;

const LogoImg = styled.img`
    height: 56px;
    width: auto;
    filter: drop-shadow(0 0 12px rgba(0,212,255,0.5));
`;

const Tagline = styled.p`
    font-size: 12px;
    letter-spacing: 3px;
    text-transform: uppercase;
    color: rgba(148,163,184,0.8);
    margin-top: 6px;
`;

const Card = styled.div`
    animation: ${popIn} 0.5s cubic-bezier(0.34,1.56,0.64,1) 0.2s both;
    background: rgba(255,255,255,0.04);
    backdrop-filter: blur(24px);
    -webkit-backdrop-filter: blur(24px);
    border: 1px solid rgba(var(--xcasper-primary-rgb, 0,212,255),0.15);
    border-radius: 20px;
    padding: 40px 36px;
    width: 100%;
    max-width: 420px;
    animation: ${popIn} 0.5s cubic-bezier(0.34,1.56,0.64,1) 0.2s both, ${pulseGlow} 4s ease-in-out 1s infinite;
`;

const CardTitle = styled.h2`
    font-size: 22px;
    font-weight: 700;
    text-align: center;
    color: #FFFFFF;
    margin-bottom: 24px;
    letter-spacing: 0.5px;
`;

const FooterLinks = styled.div`
    margin-top: 28px;
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 6px 16px;
`;

const FooterLink = styled.a`
    font-size: 11px;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: rgba(148,163,184,0.7);
    text-decoration: none;
    transition: color 0.2s;
    &:hover { color: var(--xcasper-primary, #00D4FF); }
`;

const Copyright = styled.p`
    font-size: 11px;
    text-align: center;
    color: rgba(100,116,139,0.6);
    margin-top: 12px;
    letter-spacing: 1px;
`;

const PoweredBy = styled.div`
    font-size: 10px;
    text-align: center;
    color: rgba(100,116,139,0.5);
    margin-top: 4px;
    letter-spacing: 2px;
    text-transform: uppercase;
`;

const WelcomeOverlay = styled.div<{ visible: boolean }>`
    position: fixed;
    inset: 0;
    background: rgba(var(--xcasper-bg-rgb, 5,13,31),0.85);
    backdrop-filter: blur(8px);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: ${p => p.visible ? 1 : 0};
    pointer-events: ${p => p.visible ? 'all' : 'none'};
    transition: opacity 0.4s ease;
`;

const WelcomeCard = styled.div<{ visible: boolean }>`
    background: linear-gradient(145deg, rgba(11,23,56,0.95), rgba(26,5,51,0.95));
    border: 1px solid rgba(var(--xcasper-primary-rgb, 0,212,255),0.3);
    border-radius: 24px;
    padding: 48px 40px;
    max-width: 460px;
    width: 90%;
    text-align: center;
    transform: ${p => p.visible ? 'scale(1) translateY(0)' : 'scale(0.9) translateY(20px)'};
    transition: transform 0.4s cubic-bezier(0.34,1.56,0.64,1);
    box-shadow: 0 0 60px rgba(var(--xcasper-primary-rgb, 0,212,255),0.2), 0 0 120px rgba(var(--xcasper-accent-rgb, 124,58,237),0.15);
`;

const WelcomeTitle = styled.h1`
    font-size: 28px;
    font-weight: 900;
    background: linear-gradient(90deg, var(--xcasper-primary, #00D4FF), var(--xcasper-accent, #7C3AED), var(--xcasper-primary, #00D4FF));
    background-size: 200% auto;
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    animation: ${shimmer} 3s linear infinite;
    margin-bottom: 12px;
`;

const WelcomeText = styled.p`
    color: rgba(148,163,184,0.9);
    font-size: 14px;
    line-height: 1.7;
    margin-bottom: 28px;
`;

const WelcomeButton = styled.button`
    background: linear-gradient(135deg, var(--xcasper-primary, #00D4FF), var(--xcasper-accent, #7C3AED));
    color: #FFFFFF;
    font-weight: 700;
    font-size: 13px;
    letter-spacing: 2px;
    text-transform: uppercase;
    border: none;
    border-radius: 50px;
    padding: 14px 40px;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
    box-shadow: 0 4px 24px rgba(var(--xcasper-primary-rgb, 0,212,255),0.3);
    &:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 32px rgba(var(--xcasper-primary-rgb, 0,212,255),0.5);
    }
`;

const PARTICLES = Array.from({ length: 18 }, (_, i) => ({
    id: i,
    size: Math.random() * 6 + 2,
    left: Math.random() * 100,
    delay: Math.random() * 8,
    duration: Math.random() * 10 + 12,
}));

type Props = React.DetailedHTMLProps<React.FormHTMLAttributes<HTMLFormElement>, HTMLFormElement> & {
    title?: string;
};

export default forwardRef<HTMLFormElement, Props>(({ title, ...props }, ref) => {
    const [popup, setPopup] = useState(false);

    useEffect(() => {
        if (!sessionStorage.getItem('xcasper_welcomed')) {
            const t = setTimeout(() => {
                setPopup(true);
                sessionStorage.setItem('xcasper_welcomed', '1');
            }, 600);
            return () => clearTimeout(t);
        }
    }, []);

    return (
        <>
            <PageBackground>
                <GridOverlay />
                {PARTICLES.map(p => (
                    <Particle key={p.id} size={p.size} left={p.left} delay={p.delay} duration={p.duration} />
                ))}
            </PageBackground>

            <WelcomeOverlay visible={popup}>
                <WelcomeCard visible={popup}>
                    <LogoImg src={'/assets/svgs/xcasper.svg'} style={{ height: 52, marginBottom: 20 }} />
                    <WelcomeTitle>Welcome Back!</WelcomeTitle>
                    <WelcomeText>
                        Manage your game servers with ease on <strong style={{ color: 'var(--xcasper-primary, #00D4FF)' }}>XCASPER Hosting</strong>.<br />
                        We believe in building together — your success is our mission.
                    </WelcomeText>
                    <WelcomeButton onClick={() => setPopup(false)}>Get Started</WelcomeButton>
                    <div style={{ marginTop: 20, fontSize: 11, color: 'rgba(100,116,139,0.6)', letterSpacing: 2 }}>
                        A CASPER TECH KENYA PRODUCT
                    </div>
                </WelcomeCard>
            </WelcomeOverlay>

            <PageWrapper>
                <LogoArea>
                    <LogoImg src={'/assets/svgs/xcasper.svg'} />
                    <Tagline>we believe in building together</Tagline>
                </LogoArea>

                <Card>
                    {title && <CardTitle>{title}</CardTitle>}
                    <FlashMessageRender css={tw`mb-4`} />
                    <Form {...props} ref={ref}>
                        {props.children}
                    </Form>
                </Card>

                <FooterLinks>
                    <FooterLink href="https://xcasper.space" target="_blank" rel="noopener noreferrer">Home</FooterLink>
                    <FooterLink href="https://status.xcasper.space" target="_blank" rel="noopener noreferrer">Status</FooterLink>
                    <FooterLink href="https://support.xcasper.space" target="_blank" rel="noopener noreferrer">Support</FooterLink>
                </FooterLinks>
                <Copyright>&copy; {new Date().getFullYear()} XCASPER Hosting. All rights reserved.</Copyright>
                <PoweredBy>A CASPER TECH KENYA DEVELOPERS product</PoweredBy>
            </PageWrapper>
        </>
    );
});
