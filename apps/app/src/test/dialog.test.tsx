import {render, screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {useState} from 'react';
import {describe, expect, it} from 'vitest';
import {Dialog} from '../components';

function Harness() {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>Open</button>
      {open && (
        <Dialog title="Sure?" onClose={() => setOpen(false)}>
          <button type="button">First</button>
          <button type="button">Last</button>
        </Dialog>
      )}
    </>
  );
}

describe('Dialog', () => {
  it('is labelled by its title and takes focus', async () => {
    const user = userEvent.setup();
    render(<Harness />);
    await user.click(screen.getByRole('button', {name: 'Open'}));
    const dialog = screen.getByRole('dialog', {name: 'Sure?'});
    expect(dialog).toHaveAttribute('aria-labelledby');
    expect(dialog).toHaveFocus();
  });

  it('traps Tab and Shift+Tab inside', async () => {
    const user = userEvent.setup();
    render(<Harness />);
    await user.click(screen.getByRole('button', {name: 'Open'}));
    await user.tab();
    expect(screen.getByRole('button', {name: 'First'})).toHaveFocus();
    await user.tab();
    expect(screen.getByRole('button', {name: 'Last'})).toHaveFocus();
    await user.tab();
    expect(screen.getByRole('button', {name: 'First'})).toHaveFocus();
    await user.tab({shift: true});
    expect(screen.getByRole('button', {name: 'Last'})).toHaveFocus();
  });

  it('closes on Escape and returns focus to the trigger', async () => {
    const user = userEvent.setup();
    render(<Harness />);
    const trigger = screen.getByRole('button', {name: 'Open'});
    await user.click(trigger);
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(trigger).toHaveFocus();
  });
});
