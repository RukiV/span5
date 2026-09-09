import React from "react";
import { components } from "react-select";
import { IoReturnUpBack, IoClose } from "react-icons/io5";

export function noCloseOnClick(selectProps, innerOnMouseDown) {
  return (event) => {
    if (selectProps && selectProps.menuIsOpen) {
      event.preventDefault();
      event.stopPropagation();
    } else if (innerOnMouseDown) {
      innerOnMouseDown(event);
    }
  };
}

export const NoCloseControl = (props) => (
  <components.Control
    {...props}
    innerProps={{
      ...props.innerProps,
      onMouseDown: noCloseOnClick(props.selectProps, props.innerProps.onMouseDown),
    }}
  />
);

export const NoCloseDropdownIndicator = (props) => (
  <components.DropdownIndicator
    {...props}
    innerProps={{
      ...props.innerProps,
      onMouseDown: noCloseOnClick(props.selectProps, props.innerProps.onMouseDown),
    }}
  />
);

export const CascadeControl = ({ children, cascadeCount = 0, clearFromLevel, disabled = false, ...props }) => (
  <components.Control {...props}>
    {children}
    {!disabled && cascadeCount > 0 && (
      <span
        className="cascade-back-indicator"
        onMouseDown={(event) => {
          event.stopPropagation();
          event.preventDefault();
          clearFromLevel(cascadeCount - 1);
        }}
        title="Terug na vorige vlak"
      >
        <IoReturnUpBack size={24} />
      </span>
    )}
  </components.Control>
);

// Suppress react-select's built-in clear ("x") indicator on cascades so only
// our single, consistent custom x (CascadeIndicatorsContainer) renders.
export const NoCascadeClearIndicator = () => null;

// Single, always-visible, always-clickable clear ("x") indicator for cascade
// selects. Rendered whenever there is a value (enabled, partial, or completed),
// so the x never disappears on completion and looks identical everywhere.
// react-select's built-in clear indicator is suppressed via NoCascadeClearIndicator.
export const CascadeIndicatorsContainer = (props) => {
  const { hasValue, isClearable, clearValue, selectProps, disabled = false, children } = props;
  const isClearableOpt = selectProps?.isClearable;
  return (
    <components.IndicatorsContainer {...props}>
      {!disabled && hasValue && (isClearable ?? isClearableOpt) && (
        <span
          className="cascade-clear-indicator"
          onMouseDown={(e) => { e.preventDefault(); e.stopPropagation(); clearValue(); }}
          title="Maak skoon"
        >
          <IoClose size={18} />
        </span>
      )}
      {children}
    </components.IndicatorsContainer>
  );
};

export const renderBreadcrumb = ({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel = 2, marginTop = "6px", marginBottom = "6px", disabled = false }) => (
  <div className={`breadcrumb-list${marginTop === "6px" ? " breadcrumb-list-spaced" : ""}${marginBottom === "6px" ? " breadcrumb-list-bottom-spaced" : ""}`}>
    {breadcrumbData.map((item, index) => {
      const isLast = index === breadcrumbData.length - 1;
      const showArrow = isLast ? cascadeCount < maxLevel : true;
      return (
        <React.Fragment key={item.level}>
          <button
            type="button"
            className="breadcrumb-btn"
            onClick={() => clearFromLevel(item.level + 1)}
            data-current={isLast ? "true" : "false"}
            disabled={disabled}
            title={disabled ? undefined : "Klik om vlak skoon te maak"}
          >
            {item.name}
          </button>
          {showArrow && <span className="breadcrumb-arrow">›</span>}
        </React.Fragment>
      );
    })}
  </div>
);
