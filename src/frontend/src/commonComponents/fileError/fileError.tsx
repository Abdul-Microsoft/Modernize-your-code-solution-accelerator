import { Card,Text } from "@fluentui/react-components";
import { ChevronDown, ChevronRight } from "lucide-react";
import React from "react";
import { ErrorContent } from "../errorContent/errorContent";

export const FileError = (props) => {
  const {batchSummary, expandedSections, setExpandedSections, styles}=props;
  const isExpanded = expandedSections.includes("errors");

  return (
    <>
      <Card className={styles.errorSection}>
        <div
          className={styles.sectionHeader}
          onClick={() => setExpandedSections((prev) =>
            prev.includes("errors") ? prev.filter((id) => id !== "errors") : [...prev, "errors"]
          )}
        >
          <Text weight="semibold">Errors ({batchSummary.error_count || 0})</Text>
          {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
        </div>
      </Card>

      {isExpanded && <div className={styles.errorContentScrollable}>
        {<ErrorContent batchSummary={batchSummary}/>}
      </div>}
    </>
  );
};