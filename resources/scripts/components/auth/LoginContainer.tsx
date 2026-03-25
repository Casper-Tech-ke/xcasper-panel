import React, { useEffect, useRef, useState } from 'react';
import { Link, RouteComponentProps } from 'react-router-dom';
import login from '@/api/auth/login';
import LoginFormContainer from '@/components/auth/LoginFormContainer';
import { useStoreState } from 'easy-peasy';
import { Formik, FormikHelpers } from 'formik';
import { object, string } from 'yup';
import Field from '@/components/elements/Field';
import tw from 'twin.macro';
import Button from '@/components/elements/Button';
import Reaptcha from 'reaptcha';
import useFlash from '@/plugins/useFlash';
import styled from 'styled-components/macro';

interface Values {
    username: string;
    password: string;
}

const LoginButton = styled.button`
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

const ForgotLink = styled(Link)`
    display: block;
    text-align: center;
    margin-top: 16px;
    font-size: 11px;
    letter-spacing: 2px;
    text-transform: uppercase;
    color: rgba(148,163,184,0.6);
    text-decoration: none;
    transition: color 0.2s;
    &:hover { color: var(--xcasper-primary, #00D4FF); }
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

const LoginContainer = ({ history }: RouteComponentProps) => {
    const ref = useRef<Reaptcha>(null);
    const [token, setToken] = useState('');

    const { clearFlashes, clearAndAddHttpError } = useFlash();
    const { enabled: recaptchaEnabled, siteKey } = useStoreState((state) => state.settings.data!.recaptcha);

    useEffect(() => {
        clearFlashes();
    }, []);

    const onSubmit = (values: Values, { setSubmitting }: FormikHelpers<Values>) => {
        clearFlashes();

        if (recaptchaEnabled && !token) {
            ref.current!.execute().catch((error) => {
                console.error(error);
                setSubmitting(false);
                clearAndAddHttpError({ error });
            });
            return;
        }

        login({ ...values, recaptchaData: token })
            .then((response) => {
                if (response.complete) {
                    // @ts-expect-error this is valid
                    window.location = response.intended || '/';
                    return;
                }
                history.replace('/auth/login/checkpoint', { token: response.confirmationToken });
            })
            .catch((error) => {
                console.error(error);
                setToken('');
                if (ref.current) ref.current.reset();
                setSubmitting(false);
                clearAndAddHttpError({ error });
            });
    };

    return (
        <Formik
            onSubmit={onSubmit}
            initialValues={{ username: '', password: '' }}
            validationSchema={object().shape({
                username: string().required('A username or email must be provided.'),
                password: string().required('Please enter your account password.'),
            })}
        >
            {({ isSubmitting, setSubmitting, submitForm }) => (
                <>
                    {/* reCAPTCHA — rendered outside the card so it doesn't affect form layout */}
                    {recaptchaEnabled && (
                        <Reaptcha
                            ref={ref}
                            size={'invisible'}
                            sitekey={siteKey || '_invalid_key'}
                            onVerify={(response) => {
                                setToken(response);
                                submitForm();
                            }}
                            onExpire={() => {
                                setSubmitting(false);
                                setToken('');
                            }}
                        />
                    )}

                    <LoginFormContainer title={'Login to Continue'}>
                        <InputWrapper>
                            <Field light type={'text'} label={'Username or Email'} name={'username'} disabled={isSubmitting} />
                        </InputWrapper>
                        <InputWrapper>
                            <Field light type={'password'} label={'Password'} name={'password'} disabled={isSubmitting} />
                        </InputWrapper>
                        <LoginButton type={'submit'} disabled={isSubmitting}>
                            {isSubmitting ? 'Authenticating...' : 'Login'}
                        </LoginButton>
                        <ForgotLink to={'/auth/password'}>Forgot Password?</ForgotLink>
                        <div style={{ textAlign: 'center', marginTop: 20, paddingTop: 16, borderTop: '1px solid rgba(0,212,255,0.1)' }}>
                            <span style={{ fontSize: 11, color: 'rgba(148,163,184,0.5)', letterSpacing: 1, textTransform: 'uppercase' }}>
                                No account?{' '}
                            </span>
                            <Link
                                to={'/auth/register'}
                                style={{
                                    fontSize: 11, letterSpacing: 2, textTransform: 'uppercase',
                                    color: '#00D4FF', textDecoration: 'none', fontWeight: 700, transition: 'opacity 0.2s',
                                }}
                            >
                                Create one here
                            </Link>
                        </div>
                        {recaptchaEnabled && (
                            <p style={{ fontSize: 10, textAlign: 'center', color: 'rgba(100,116,139,0.45)', marginTop: 16, lineHeight: 1.6 }}>
                                Protected by reCAPTCHA —{' '}
                                <a href="https://policies.google.com/privacy" target="_blank" rel="noreferrer"
                                   style={{ color: 'rgba(100,116,139,0.6)', textDecoration: 'underline' }}>Privacy</a>
                                {' '}·{' '}
                                <a href="https://policies.google.com/terms" target="_blank" rel="noreferrer"
                                   style={{ color: 'rgba(100,116,139,0.6)', textDecoration: 'underline' }}>Terms</a>
                            </p>
                        )}
                    </LoginFormContainer>
                </>
            )}
        </Formik>
    );
};

export default LoginContainer;
