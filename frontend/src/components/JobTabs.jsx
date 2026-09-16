import React, { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { apiClient } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import { useToast } from '../components/Toast/useToast';

/**
 * JobTabs — tab chrome shared by the Werksopdragte (work orders) page and
 * the Voorgestelde Werksopdragte (AI job-draft queue/new/detail) pages.
 *
 * Renders a tab bar above the routed page content. The AI tab is only shown to
 * users holding the `ai.approve` right; its badge shows the number of drafts
 * still waiting for approval. The active tab is derived from the current URL.
 */
function JobTabs({ children }) {
  const location = useLocation();
  const { hasRight } = useCurrentUser();
  const { showToast } = useToast();
  const canApprove = hasRight('ai.approve');
  const isAi = location.pathname === '/ai-drafts' || location.pathname.startsWith('/ai-drafts/');
  const [pendingCount, setPendingCount] = useState(0);

  useEffect(() => {
    if (!canApprove) return;
    let cancelled = false;
    apiClient.jobDrafts
      .getAll({ status_filter: 'draft' })
      .then((res) => {
        if (!cancelled) setPendingCount(Array.isArray(res.data) ? res.data.length : 0);
      })
      .catch(() => {
        if (!cancelled) showToast({ type: 'error', title: 'Fout', message: 'Kon nie die voorgestelde-werksopdragtelling laai nie' });
      });
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canApprove, location.pathname]);

  // Zonder die ai.approve-reg is daar net een tab — verberg die strook dan heel.
  if (!canApprove) return <>{children}</>;

  return (
    <>
      <div className="fault-tabs">
        <Link
          to="/work-orders"
          className={`fault-tab${isAi ? '' : ' active'}`}
        >
          Werksopdragte
        </Link>
        <Link
          to="/ai-drafts"
          className={`fault-tab${isAi ? ' active' : ''}`}
        >
          Voorgestelde Werksopdragte
          {pendingCount > 0 && <span className="fault-tab-badge">{pendingCount}</span>}
        </Link>
      </div>
      {children}
    </>
  );
}

export default JobTabs;