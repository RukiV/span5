import '@testing-library/jest-dom';
import { render, screen, fireEvent } from '@testing-library/react';
import Modal from '../components/Modal/Modal';
import ConfirmDialog from '../components/Modal/ConfirmDialog';

describe('Modal', () => {
  test('renders with title and content', () => {
    render(
      <Modal isOpen={true} onClose={jest.fn()} title="Test Modal">
        <p>Modal content</p>
      </Modal>
    );
    expect(screen.getByText('Test Modal')).toBeInTheDocument();
    expect(screen.getByText('Modal content')).toBeInTheDocument();
  });

  test('does not render when isOpen is false', () => {
    render(
      <Modal isOpen={false} onClose={jest.fn()} title="Hidden">
        <p>Should not appear</p>
      </Modal>
    );
    expect(screen.queryByText('Hidden')).not.toBeInTheDocument();
  });

  test('calls onClose when backdrop is clicked', () => {
    const onClose = jest.fn();
    const { container } = render(
      <Modal isOpen={true} onClose={onClose} title="Backdrop Test">
        <p>Content</p>
      </Modal>
    );
    const overlay = container.querySelector('.modal-overlay') || container.firstChild;
    if (overlay) fireEvent.click(overlay);
    expect(onClose).toHaveBeenCalled();
  });

  test('renders in different sizes', () => {
    const { container: sm } = render(<Modal isOpen={true} onClose={jest.fn()} title="Sm" size="sm"><p>sm</p></Modal>);
    const { container: lg } = render(<Modal isOpen={true} onClose={jest.fn()} title="Lg" size="lg"><p>lg</p></Modal>);
    expect(sm.textContent).toContain('sm');
    expect(lg.textContent).toContain('lg');
  });
});

describe('ConfirmDialog', () => {
  test('renders with message and buttons', () => {
    render(
      <ConfirmDialog
        isOpen={true}
        onClose={jest.fn()}
        onConfirm={jest.fn()}
        title="Confirm?"
        message="Are you sure?"
        confirmLabel="Ja"
        cancelLabel="Nee"
        variant="danger"
      />
    );
    expect(screen.getByText('Confirm?')).toBeInTheDocument();
    expect(screen.getByText('Are you sure?')).toBeInTheDocument();
    expect(screen.getByText('Ja')).toBeInTheDocument();
    expect(screen.getByText('Nee')).toBeInTheDocument();
  });

  test('calls onConfirm when confirm button clicked', () => {
    const onConfirm = jest.fn();
    render(
      <ConfirmDialog isOpen={true} onClose={jest.fn()} onConfirm={onConfirm}
        title="Test" message="Test message" confirmLabel="Ja" cancelLabel="Nee" />
    );
    fireEvent.click(screen.getByText('Ja'));
    expect(onConfirm).toHaveBeenCalled();
  });

  test('calls onClose when cancel button clicked', () => {
    const onClose = jest.fn();
    render(
      <ConfirmDialog isOpen={true} onClose={onClose} onConfirm={jest.fn()}
        title="Test" message="Test" confirmLabel="Ja" cancelLabel="Nee" />
    );
    fireEvent.click(screen.getByText('Nee'));
    expect(onClose).toHaveBeenCalled();
  });
});
