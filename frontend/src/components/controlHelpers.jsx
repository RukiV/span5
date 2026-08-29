import React from "react";
import { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";

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

export const CascadeControl = ({ children, cascadeCount = 0, clearFromLevel, ...props }) => (
  <components.Control
    {...props}
    innerProps={{
      ...props.innerProps,
      onMouseDown: noCloseOnClick(props.selectProps, props.innerProps.onMouseDown),
    }}
  >
    {children}
    {cascadeCount > 0 && (
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

export const renderBreadcrumb = ({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel = 2, marginTop = "6px", marginBottom = "6px" }) => (
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
          >
            {item.name}
          </button>
          {showArrow && <span className="breadcrumb-arrow">›</span>}
        </React.Fragment>
      );
    })}
  </div>
);
