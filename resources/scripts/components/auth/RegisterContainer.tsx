import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Formik, FormikHelpers } from 'formik';
import { object, string, ref } from 'yup';
import styled from 'styled-components/macro';
import LoginFormContainer from '@/components/auth/LoginFormContainer';
import Field from '@/components/elements/Field';
import useFlash from '@/plugins/useFlash';
import register from '@/api/auth/register';

interface Values {
    email: string;
    username: string;
    name_first: string;
    name_last: string;
    password: string;
    password_confirmation: string;
}

const SubmitButton = styled.button`
    width: 100%;
    padding: 13px;
    border: none;
    border-radius: 10px;
    background: linear-gradient(135deg, var(--xcasper-primary, #00D4FF), var(--xcasper-accent, #7C3AED));
    color: #FFFFFF;
    font-weight: 700;
    font-size: 14px;
    letter-spacing: 2px;
    text-transform: uppercase;
    cursor: pointer;
    margin-top: 8px;
    transition: transform 0.2s, box-shadow 0.2s, opacity 0.2s;
    box-shadow: 0 4px 20px rgba(var(--xcasper-primary-rgb, 0,212,255),0.25);
    &:hover:not(:disabled) {
        transform: translateY(-2px);
        box-shadow: 0 8px 28px rgba(var(--xcasper-primary-rgb, 0,212,255),0.45);
    }
    &:disabled {
        opacity: 0.6;
        cursor: not-allowed;
    }
`;

const InputWrapper = styled.div`
    margin-bottom: 16px;
    label {
        display: block;
        font-size: 11px;
        letter-spacing: 2px;
        text-transform: uppercase;
        color: rgba(148,163,184,0.8);
        margin-bottom: 6px;
    }
    input {
        width: 100%;
        background: rgba(255,255,255,0.06);
        border: 1px solid rgba(0,212,255,0.2);
        border-radius: 10px;
        padding: 12px 14px;
        color: #FFFFFF;
        font-size: 14px;
        outline: none;
        transition: border-color 0.2s, box-shadow 0.2s;
        box-sizing: border-box;
        &:focus {
            border-color: rgba(var(--xcasper-primary-rgb, 0,212,255),0.6);
            box-shadow: 0 0 0 3px rgba(var(--xcasper-primary-rgb, 0,212,255),0.1);
        }
        &::placeholder { color: rgba(148,163,184,0.4); }
        &:disabled { opacity: 0.5; }
    }
`;

const NameRow = styled.div`
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
`;

const BottomLink = styled(Link)`
    display: block;
    text-align: center;
    margin-top: 16px;
    font-size: 11px;
    letter-spacing: 2px;
    text-transform: uppercase;
    color: rgba(148,163,184,0.6);
    text-decoration: none;
    transition: color 0.2s;
    &:hover { color: #00D4FF; }
`;

const EmailSentScreen = ({ email, onBack }: { email: string; onBack: string }) => (
    <div style={{
        position: 'fixed',
        inset: 0,
        background: '#0f172a',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px 16px',
        fontFamily: "'Inter', Arial, sans-serif",
    }}>
        <div style={{ marginBottom: 24, textAlign: 'center' }}>
            <span style={{ fontSize: 24, fontWeight: 800, letterSpacing: 3, color: '#00D4FF', textTransform: 'uppercase' }}>X</span>
            <span style={{ fontSize: 24, fontWeight: 800, letterSpacing: 3, color: '#a78bfa', textTransform: 'uppercase' }}>CASPER</span>
            <p style={{ fontSize: 10, letterSpacing: 3, textTransform: 'uppercase', color: 'rgba(148,163,184,0.8)', marginTop: 6 }}>
                we believe in building together
            </p>
        </div>
        <div style={{
            background: 'rgba(255,255,255,0.04)',
            border: '1px solid rgba(0,212,255,0.15)',
            borderRadius: 20,
            padding: '40px 36px',
            width: '100%',
            maxWidth: 420,
            textAlign: 'center',
        }}>
            <div style={{ fontSize: 48, marginBottom: 20 }}>&#128231;</div>
            <h2 style={{ fontSize: 22, fontWeight: 700, color: '#ffffff', marginBottom: 16 }}>Check Your Email</h2>
            <p style={{ color: 'rgba(148,163,184,0.9)', fontSize: 14, lineHeight: 1.6, marginBottom: 8 }}>
                We sent a verification link to
            </p>
            <p style={{ color: '#00D4FF', fontSize: 15, fontWeight: 700, marginBottom: 20, wordBreak: 'break-all' }}>
                {email}
            </p>
            <p style={{ color: 'rgba(148,163,184,0.7)', fontSize: 12, lineHeight: 1.7, marginBottom: 24 }}>
                Click the link in the email to activate your account. The link expires in 24 hours. Check your spam folder if you don&apos;t see it.
            </p>
            <Link
                to={onBack}
                style={{
                    display: 'block',
                    textAlign: 'center',
                    fontSize: 11,
                    letterSpacing: 2,
                    textTransform: 'uppercase',
                    color: 'rgba(148,163,184,0.6)',
                    textDecoration: 'none',
                }}
            >
                Back to Login
            </Link>
        </div>
    </div>
);

const RegisterContainer = () => {
    const [sent, setSent] = useState(false);
    const [sentEmail, setSentEmail] = useState('');
    const { clearFlashes, clearAndAddHttpError } = useFlash();

    const onSubmit = (values: Values, { setSubmitting }: FormikHelpers<Values>) => {
        clearFlashes();
        register(values)
            .then(() => {
                setSentEmail(values.email);
                setSent(true);
            })
            .catch((error) => {
                console.error(error);
                setSubmitting(false);
                clearAndAddHttpError({ error });
            });
    };

    if (sent) {
        return <EmailSentScreen email={sentEmail} onBack={'/auth/login'} />;
    }

    return (
        <Formik
            onSubmit={onSubmit}
            initialValues={{
                email: '',
                username: '',
                name_first: '',
                name_last: '',
                password: '',
                password_confirmation: '',
            }}
            validationSchema={object().shape({
                email: string()
                    .email('Please enter a valid email address.')
                    .required('An email address is required.')
                    .test('allowed-domain', 'Only Gmail (@gmail.com) and Outlook (@outlook.com / @hotmail.com) addresses are accepted.', (value) => {
                        if (!value) return false;
                        const lower = value.toLowerCase();
                        return lower.endsWith('@gmail.com') || lower.endsWith('@outlook.com') || lower.endsWith('@hotmail.com');
                    }),
                username: string().min(3, 'Username must be at least 3 characters.').max(30).matches(/^[a-zA-Z0-9]+$/, 'Username can only contain letters and numbers.').required('A username is required.'),
                name_first: string().required('First name is required.').max(50),
                name_last: string().required('Last name is required.').max(50),
                password: string().min(8, 'Password must be at least 8 characters.').required('A password is required.'),
                password_confirmation: string()
                    .oneOf([ref('password')], 'Passwords do not match.')
                    .required('Please confirm your password.'),
            })}
        >
            {({ isSubmitting }) => (
                <LoginFormContainer title={'Create an Account'}>
                    <NameRow>
                        <InputWrapper>
                            <Field light type={'text'} label={'First Name'} name={'name_first'} disabled={isSubmitting} />
                        </InputWrapper>
                        <InputWrapper>
                            <Field light type={'text'} label={'Last Name'} name={'name_last'} disabled={isSubmitting} />
                        </InputWrapper>
                    </NameRow>
                    <InputWrapper>
                        <Field light type={'email'} label={'Email Address'} name={'email'} disabled={isSubmitting} />
                        <p style={{ fontSize: 11, color: 'rgba(100,116,139,0.7)', marginTop: 4, letterSpacing: 1 }}>
                            Gmail or Outlook addresses only
                        </p>
                    </InputWrapper>
                    <InputWrapper>
                        <Field light type={'text'} label={'Username'} name={'username'} disabled={isSubmitting} />
                    </InputWrapper>
                    <InputWrapper>
                        <Field light type={'password'} label={'Password'} name={'password'} disabled={isSubmitting} />
                    </InputWrapper>
                    <InputWrapper>
                        <Field light type={'password'} label={'Confirm Password'} name={'password_confirmation'} disabled={isSubmitting} />
                    </InputWrapper>
                    <SubmitButton type={'submit'} disabled={isSubmitting}>
                        {isSubmitting ? 'Creating Account...' : 'Create Account'}
                    </SubmitButton>
                    <BottomLink to={'/auth/login'}>Already have an account? Log in</BottomLink>
                </LoginFormContainer>
            )}
        </Formik>
    );
};

export default RegisterContainer;
