"""Mask sensitive KYC fields for API responses."""


def mask_pan(pan: str) -> str:
    pan = (pan or '').upper().strip()
    if len(pan) != 10:
        return '****'
    return f'{pan[:2]}*****{pan[-2:]}'


def mask_account_number(account: str) -> str:
    acct = (account or '').strip()
    if len(acct) <= 4:
        return acct
    return f'****{acct[-4:]}'
