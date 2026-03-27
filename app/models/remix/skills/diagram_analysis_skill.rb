module Remix
  module Skills
    class DiagramAnalysisSkill < BaseSkill
      def self.name = 'diagram_analysis'
      def self.description = 'Help with understanding and optimizing flow diagrams'

      def self.triggers
        ['diagram', 'flow', 'visualize', 'connections', 'architecture',
         'structure', 'analyze flow', 'optimize']
      end

      def self.context(user)
        <<~CONTEXT
          ## Flow Diagram Analysis Guide

          ### Understanding Flow Diagrams
          - **Boxes** represent agents
          - **Arrows** show event flow (source → receiver)
          - **Dashed lines** indicate delayed propagation (not immediate)
          - **Control links** show which agents can enable/disable others

          ### Reading Agent Status
          - **✓** Agent is working (recently checked and produced events)
          - **✗** Agent is not working (may need attention)
          - **Grayed out** Agent is disabled

          ### Common Flow Patterns

          **Linear Pipeline**
          ```
          Source → Processor → Filter → Output
          ```
          Good for: Sequential data processing

          **Fan-Out (Broadcast)**
          ```
                    → Output1
          Source → → Output2
                    → Output3
          ```
          Good for: Sending same data to multiple destinations

          **Fan-In (Aggregation)**
          ```
          Source1 →
          Source2 → Processor → Output
          Source3 →
          ```
          Good for: Combining data from multiple sources

          **Conditional Routing**
          ```
          Source → Trigger → Output (only when condition met)
          ```
          Good for: Filtering and conditional logic

          ### Analyzing Flow Issues

          #### Isolated Agents
          - Agents with no connections won't do anything useful
          - Either connect them or remove them

          #### Bottlenecks
          - One agent receiving from many sources
          - May need to increase processing frequency
          - Consider parallelizing with multiple processors

          #### Circular Dependencies
          - Agent A → Agent B → Agent A
          - Can cause infinite loops
          - Use guards or counters in agent memory

          #### Dead Ends
          - Agents that create events but have no receivers
          - May be intentional (logging) or a mistake
          - Use `analyze_flow` to identify

          ### Optimization Tips
          1. **Minimize Poll Frequency**: Don't check sources too often
          2. **Use Propagate Immediately**: For real-time workflows
          3. **Batch Processing**: Collect events before processing
          4. **Control Links**: Disable agents when not needed
          5. **Memory Management**: Set appropriate keep_events_for values
        CONTEXT
      end
    end
  end
end
