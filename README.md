# Decentralized Workflow Hub

An advanced smart contract platform for coordinating distributed team workflows on the Stacks blockchain. Built for enterprises that demand transparent, auditable, and tamper-proof task execution across teams.

## What This Does

Decentralized Workflow Hub provides cryptographically-secured workflow coordination. Instead of relying on centralized databases or project management tools, teams use this smart contract to orchestrate work, track dependencies, and maintain immutable records of all activities.

**Key capabilities:**
- Distributed workflow creation and state management
- Complex assignment orchestration with precedence constraints
- Fine-grained permission levels for multi-stakeholder environments
- Cryptographic proof of work completion via deliverable hashing
- Comprehensive audit logging for compliance
- Checkpoint-based milestone tracking with payment integration
- Work effort tracking and contribution recording

## Why Blockchain-Based Workflows?

Traditional project management creates data silos and relies on trust. This contract provides:
- **Transparency**: Every action is immutable and verifiable
- **Trust elimination**: Math, not people, enforces rules
- **Auditability**: Complete history of who did what, when
- **Interoperability**: Other contracts can read completion status

## System Design

The workflow hub organizes work into hierarchical structures:

```
Workflow (Initiative)
├── Participants (Team members with permission levels)
├── Assignments (Granular work items)
│   ├── Dependencies (Precedence requirements)
│   ├── Work Records (Hourly contributions)
│   └── Discussion Notes (Collaboration)
└── Checkpoints (Milestone payments/verification)
```

## Permission Model

Four access levels control what team members can do:
- **Lead**: Full control (typically workflow initiator)
- **Admin**: Modify structure and permissions
- **Operator**: Create/update work, record contributions
- **Observer**: Read-only access to workflow state

## Getting Started

### Installation & Setup

Install Clarinet (if needed):
```bash
brew install clarinet
```

Clone this repository and install dependencies:
```bash
cd decentralized-workflow-hub
clarinet install
```

### Running Tests

The test suite validates all functionality:
```bash
clarinet test
```

Tests cover:
- Workflow creation and configuration
- Permission enforcement across all access levels
- Participant enrollment and role management
- Assignment lifecycle and state transitions
- Dependency chain validation
- Edge cases and error conditions

### Local Development

Start a local blockchain for development:
```bash
clarinet integrate
```

This launches the Clarinet console where you can call contract functions interactively.

## API Reference

### Workflow Operations

Initialize a new workflow:
```clarity
(setup-workflow 
  (name (string-utf8 100))
  (detail (string-utf8 500))
  (start-block uint)
  (end-block uint)
  (cost-alloc uint))
```

Retrieve workflow data:
```clarity
(query-workflow (flow-id uint))
```

Modify workflow parameters (admin/lead only):
```clarity
(update-workflow
  (flow-id uint)
  (name (string-utf8 100))
  (detail (string-utf8 500))
  (state uint)
  (start-block uint)
  (end-block uint)
  (cost-alloc uint))
```

### Team Coordination

Add team members to workflow:
```clarity
(enroll-participant
  (flow-id uint)
  (party principal)
  (perm-level uint))
```

Adjust participant permissions:
```clarity
(reassign-participant-role
  (flow-id uint)
  (party principal)
  (new-perm-level uint))
```

Remove participants (cannot remove lead):
```clarity
(remove-participant
  (flow-id uint)
  (party principal))
```

### Assignment Management

Create assignments:
```clarity
(create-assignment
  (flow-id uint)
  (name (string-utf8 100))
  (detail (string-utf8 500))
  (operator (optional principal))
  (severity uint)
  (hours-needed uint)
  (start-block uint)
  (finish-block uint)
  (checkpoint-id (optional uint)))
```

Update assignment metadata:
```clarity
(update-assignment
  (flow-id uint)
  (assign-id uint)
  ... [same params as create])
```

Query assignment details:
```clarity
(query-assignment (flow-id uint) (assign-id uint))
```

Transition assignment states:
```clarity
(transition-assignment-state
  (flow-id uint)
  (assign-id uint)
  (new-state uint))
```

### Work Recording

Report time spent:
```clarity
(report-work
  (flow-id uint)
  (assign-id uint)
  (hours-worked uint)
  (note-text (string-utf8 200)))
```

Add discussion notes:
```clarity
(write-note
  (flow-id uint)
  (assign-id uint)
  (message (string-utf8 500)))
```

### Deliverables & Verification

Attach cryptographic proof of completion:
```clarity
(attach-output
  (flow-id uint)
  (assign-id uint)
  (output-hash (buff 32)))
```

### Dependency Management

Create assignment precedence constraints:
```clarity
(establish-precedence
  (flow-id uint)
  (assign-id uint)
  (prior-assign-id uint))
```

Remove dependencies:
```clarity
(dissolve-precedence
  (flow-id uint)
  (assign-id uint)
  (prior-assign-id uint))
```

### Milestone Checkpoints

Create payment/verification milestones:
```clarity
(establish-checkpoint
  (flow-id uint)
  (name (string-utf8 100))
  (detail (string-utf8 500))
  (finish-block uint)
  (payout uint))
```

## Architecture Highlights

**Efficient State Management**: The contract uses hierarchical maps to organize data:
- Workflows indexed by ID
- Assignments indexed by (workflow, assignment) tuple
- Participants tracked with permission bitmaps
- Activity logged for compliance

**Immutable Audit Trail**: Every state change records:
- Who made the change
- What changed
- When it happened
- Which workflow/assignment affected

**Dependency Validation**: Complex workflows require tasks to complete in order. The contract enforces prerequisite satisfaction before state transitions.

**Atomic Operations**: State updates are atomic—partial failures never leave data inconsistent.

## Security Features

1. **Permission Enforcement**: Every mutating operation validates caller permissions
2. **Circular Dependency Prevention**: Cannot create dependency where task depends on itself
3. **Self-Assignment Protection**: Owner role cannot be removed
4. **State Validation**: Assignment state changes only allow valid transitions
5. **Prerequisite Checking**: Tasks cannot start until dependencies complete

## Limitations & Future Enhancements

Current version:
- Does not support bulk operations
- No soft-delete capability (assignments cancelled, not removed)
- External storage required for large deliverables (only hash stored)
- No payment distribution logic (framework ready)

Roadmap:
- Batch workflow operations
- Integration with SIP-010 token contracts for payments
- Advanced reporting and analytics views
- Cross-chain interoperability

## Contributing

This is a production-ready smart contract. Modifications should:
1. Maintain backward compatibility of state storage
2. Pass all existing tests
3. Add new tests for new functionality
4. Follow Clarity style conventions

## License

MIT