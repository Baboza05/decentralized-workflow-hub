;; Decentralized Workflow Hub - Process Orchestrator
;;
;; Enterprise-grade workflow coordination platform built on Stacks
;; Manages distributed task execution, team coordination, and milestone tracking
;; with cryptographic proof of completion and transparent audit records.

;; Error definitions
(define-constant error-not-permitted (err u100))
(define-constant error-workflow-missing (err u101))
(define-constant error-assignment-missing (err u102))
(define-constant error-participant-missing (err u103))
(define-constant error-state-invalid (err u104))
(define-constant error-permission-level-invalid (err u105))
(define-constant error-record-exists (err u106))
(define-constant error-checkpoint-missing (err u107))
(define-constant error-params-invalid (err u108))
(define-constant error-chain-incomplete (err u109))
(define-constant error-checkpoint-unpaid (err u110))
(define-constant error-balance-low (err u111))

;; Workflow state constants
(define-constant state-prep u1)
(define-constant state-running u2)
(define-constant state-suspended u3)
(define-constant state-done u4)
(define-constant state-aborted u5)

;; Assignment state constants
(define-constant assign-state-pending u1)
(define-constant assign-state-active u2)
(define-constant assign-state-under-review u3)
(define-constant assign-state-finished u4)
(define-constant assign-state-cancelled u5)

;; Permission levels
(define-constant perm-lead u1)
(define-constant perm-admin u2)
(define-constant perm-operator u3)
(define-constant perm-observer u4)

;; Data storage structures

;; Workflow registry
(define-map workflow-registry
  { flow-id: uint }
  {
    name: (string-utf8 100),
    detail: (string-utf8 500),
    coordinator: principal,
    state: uint,
    start-block: uint,
    end-block: uint,
    cost-alloc: uint,
    created-block: uint,
    modified-block: uint
  }
)

;; Assignment tracking
(define-map assignment-tracking
  { flow-id: uint, assign-id: uint }
  {
    name: (string-utf8 100),
    detail: (string-utf8 500),
    operator: (optional principal),
    state: uint,
    severity: uint,
    hours-needed: uint,
    start-block: uint,
    finish-block: uint,
    created-block: uint,
    modified-block: uint,
    checkpoint-id: (optional uint),
    output-hash: (optional (buff 32))
  }
)

;; Precedence tracking (assignment dependencies)
(define-map precedence-tracking
  { flow-id: uint, assign-id: uint, prior-assign-id: uint }
  { linked: bool }
)

;; Checkpoint registry
(define-map checkpoint-registry
  { flow-id: uint, checkpoint-id: uint }
  {
    name: (string-utf8 100),
    detail: (string-utf8 500),
    finish-block: uint,
    payout: uint,
    complete: bool,
    settled: bool
  }
)

;; Participant roster with access levels
(define-map participant-roster
  { flow-id: uint, party: principal }
  {
    perm-level: uint,
    entry-block: uint
  }
)

;; Operation log - immutable record
(define-map operation-log
  { flow-id: uint, op-id: uint }
  {
    executor: principal,
    op-class: (string-utf8 50),
    op-desc: (string-utf8 200),
    op-block: uint,
    assign-id: (optional uint),
    checkpoint-id: (optional uint)
  }
)

;; Sequential ID counters
(define-data-var current-flow-id uint u1)
(define-map flow-assign-seq { flow-id: uint } { counter: uint })
(define-map flow-checkpoint-seq { flow-id: uint } { counter: uint })
(define-map flow-operation-seq { flow-id: uint } { counter: uint })
(define-map flow-work-record-seq { flow-id: uint, assign-id: uint } { counter: uint })
(define-map flow-note-seq { flow-id: uint, assign-id: uint } { counter: uint })

;; Auxiliary data structures
(define-map work-records
  { flow-id: uint, assign-id: uint, record-id: uint }
  {
    contributor: principal,
    hours-worked: uint,
    note-text: (string-utf8 200),
    recorded-block: uint
  }
)

(define-map task-notes
  { flow-id: uint, assign-id: uint, note-id: uint }
  {
    writer: principal,
    message: (string-utf8 500),
    written-block: uint
  }
)

;; Private utility functions

;; Generate next sequential workflow ID
(define-private (fetch-next-flow-id)
  (let ((current (var-get current-flow-id)))
    (var-set current-flow-id (+ current u1))
    current))

;; Get and increment assignment counter for workflow
(define-private (fetch-next-assign-id (flow-id uint))
  (let ((counter-record (default-to { counter: u1 } (map-get? flow-assign-seq { flow-id: flow-id }))))
    (map-set flow-assign-seq 
      { flow-id: flow-id } 
      { counter: (+ (get counter counter-record) u1) })
    (get counter counter-record)))

;; Get and increment checkpoint counter for workflow
(define-private (fetch-next-checkpoint-id (flow-id uint))
  (let ((counter-record (default-to { counter: u1 } (map-get? flow-checkpoint-seq { flow-id: flow-id }))))
    (map-set flow-checkpoint-seq 
      { flow-id: flow-id } 
      { counter: (+ (get counter counter-record) u1) })
    (get counter counter-record)))

;; Get and increment operation counter for workflow
(define-private (fetch-next-operation-id (flow-id uint))
  (let ((counter-record (default-to { counter: u1 } (map-get? flow-operation-seq { flow-id: flow-id }))))
    (map-set flow-operation-seq 
      { flow-id: flow-id } 
      { counter: (+ (get counter counter-record) u1) })
    (get counter counter-record)))

;; Get and increment work record counter for assignment
(define-private (fetch-next-work-record-id (flow-id uint) (assign-id uint))
  (let ((counter-record (default-to { counter: u1 } (map-get? flow-work-record-seq { flow-id: flow-id, assign-id: assign-id }))))
    (map-set flow-work-record-seq 
      { flow-id: flow-id, assign-id: assign-id } 
      { counter: (+ (get counter counter-record) u1) })
    (get counter counter-record)))

;; Get and increment note counter for assignment
(define-private (fetch-next-note-id (flow-id uint) (assign-id uint))
  (let ((counter-record (default-to { counter: u1 } (map-get? flow-note-seq { flow-id: flow-id, assign-id: assign-id }))))
    (map-set flow-note-seq 
      { flow-id: flow-id, assign-id: assign-id } 
      { counter: (+ (get counter counter-record) u1) })
    (get counter counter-record)))

;; Verify caller has sufficient permissions
(define-private (verify-access (flow-id uint) (caller principal) (min-perm uint))
  (let ((participant-data (map-get? participant-roster { flow-id: flow-id, party: caller })))
    (and 
      (is-some participant-data)
      (<= (unwrap-panic (get perm-level participant-data)) min-perm))))

;; Record workflow event
(define-private (record-event (flow-id uint) (op-class (string-utf8 50)) (op-desc (string-utf8 200)) (assign-id (optional uint)) (checkpoint-id (optional uint)))
  (let ((op-id (fetch-next-operation-id flow-id)))
    (map-set operation-log
      { flow-id: flow-id, op-id: op-id }
      {
        executor: tx-sender,
        op-class: op-class,
        op-desc: op-desc,
        op-block: block-height,
        assign-id: assign-id,
        checkpoint-id: checkpoint-id
      })))

;; Check assignment prerequisites are satisfied
(define-private (verify-prerequisites (flow-id uint) (assign-id uint))
  ;; Implementation would validate all dependencies are in finished state
  true)

;; Validate milestone task completion
(define-private (validate-checkpoint-ready (flow-id uint) (checkpoint-id uint))
  ;; Implementation would check all related assignments are finished
  true)

;; Read-only query functions

;; Retrieve workflow information
(define-read-only (query-workflow (flow-id uint))
  (map-get? workflow-registry { flow-id: flow-id }))

;; Retrieve assignment information
(define-read-only (query-assignment (flow-id uint) (assign-id uint))
  (map-get? assignment-tracking { flow-id: flow-id, assign-id: assign-id }))

;; Retrieve checkpoint information
(define-read-only (query-checkpoint (flow-id uint) (checkpoint-id uint))
  (map-get? checkpoint-registry { flow-id: flow-id, milestone-id: checkpoint-id }))

;; Check participant membership
(define-read-only (has-participant-role (flow-id uint) (party principal))
  (is-some (map-get? participant-roster { flow-id: flow-id, party: party })))

;; Query participant's permission level
(define-read-only (fetch-participant-level (flow-id uint) (party principal))
  (get perm-level (default-to { perm-level: u0, entry-block: u0 } (map-get? participant-roster { flow-id: flow-id, party: party }))))

;; Public transaction functions

;; Initialize new workflow
(define-public (setup-workflow 
  (name (string-utf8 100)) 
  (detail (string-utf8 500))
  (start-block uint)
  (end-block uint)
  (cost-alloc uint))
  
  (let ((flow-id (fetch-next-flow-id)))
    ;; Create workflow entry
    (map-set workflow-registry
      { flow-id: flow-id }
      {
        name: name,
        detail: detail,
        coordinator: tx-sender,
        state: state-prep,
        start-block: start-block,
        end-block: end-block,
        cost-alloc: cost-alloc,
        created-block: block-height,
        modified-block: block-height
      })
    
    ;; Register creator as lead
    (map-set participant-roster
      { flow-id: flow-id, party: tx-sender }
      {
        perm-level: perm-lead,
        entry-block: block-height
      })
    
    ;; Record event
    (record-event flow-id u"workflow-init" u"Workflow established" none none)
    
    (ok flow-id)))

;; Modify workflow parameters
(define-public (update-workflow
  (flow-id uint)
  (name (string-utf8 100))
  (detail (string-utf8 500))
  (state uint)
  (start-block uint)
  (end-block uint)
  (cost-alloc uint))
  
  (let ((workflow-data (map-get? workflow-registry { flow-id: flow-id })))
    ;; Verify workflow existence
    (asserts! (is-some workflow-data) error-workflow-missing)
    
    ;; Verify authorization (admin or lead)
    (asserts! (verify-access flow-id tx-sender perm-admin) error-not-permitted)
    
    ;; Update workflow
    (map-set workflow-registry
      { flow-id: flow-id }
      {
        name: name,
        detail: detail,
        coordinator: (get coordinator (unwrap-panic workflow-data)),
        state: state,
        start-block: start-block,
        end-block: end-block,
        cost-alloc: cost-alloc,
        created-block: (get created-block (unwrap-panic workflow-data)),
        modified-block: block-height
      })
    
    ;; Record event
    (record-event flow-id u"workflow-update" u"Workflow modified" none none)
    
    (ok true)))

;; Add participant to workflow
(define-public (enroll-participant
  (flow-id uint)
  (party principal)
  (perm-level uint))
  
  (let ((workflow-data (map-get? workflow-registry { flow-id: flow-id })))
    ;; Verify workflow existence
    (asserts! (is-some workflow-data) error-workflow-missing)
    
    ;; Verify authorization (admin or lead)
    (asserts! (verify-access flow-id tx-sender perm-admin) error-not-permitted)
    
    ;; Verify permission level validity
    (asserts! (and (>= perm-level perm-observer) (<= perm-level perm-lead)) error-permission-level-invalid)
    
    ;; Check participant not already enrolled
    (asserts! (not (has-participant-role flow-id party)) error-record-exists)
    
    ;; Enroll participant
    (map-set participant-roster
      { flow-id: flow-id, party: party }
      {
        perm-level: perm-level,
        entry-block: block-height
      })
    
    ;; Record event
    (record-event flow-id u"participant-add" u"New participant enrolled" none none)
    
    (ok true)))

;; Update participant's permission level
(define-public (reassign-participant-role
  (flow-id uint)
  (party principal)
  (new-perm-level uint))
  
  (let ((workflow-data (map-get? workflow-registry { flow-id: flow-id }))
        (participant-data (map-get? participant-roster { flow-id: flow-id, party: party })))
    ;; Verify workflow existence
    (asserts! (is-some workflow-data) error-workflow-missing)
    
    ;; Verify participant existence
    (asserts! (is-some participant-data) error-participant-missing)
    
    ;; Verify authorization (admin or lead)
    (asserts! (verify-access flow-id tx-sender perm-admin) error-not-permitted)
    
    ;; Verify permission level validity
    (asserts! (and (>= new-perm-level perm-observer) (<= new-perm-level perm-lead)) error-permission-level-invalid)
    
    ;; Update permission level
    (map-set participant-roster
      { flow-id: flow-id, party: party }
      {
        perm-level: new-perm-level,
        entry-block: (get entry-block (unwrap-panic participant-data))
      })
    
    ;; Record event
    (record-event flow-id u"role-change" u"Participant permissions updated" none none)
    
    (ok true)))

;; Remove participant from workflow
(define-public (remove-participant
  (flow-id uint)
  (party principal))
  
  (let ((workflow-data (map-get? workflow-registry { flow-id: flow-id })))
    ;; Verify workflow existence
    (asserts! (is-some workflow-data) error-workflow-missing)
    
    ;; Verify authorization (admin or lead)
    (asserts! (verify-access flow-id tx-sender perm-admin) error-not-permitted)
    
    ;; Prevent removal of coordinator
    (asserts! (not (is-eq party (get coordinator (unwrap-panic workflow-data)))) error-not-permitted)
    
    ;; Remove participant
    (map-delete participant-roster { flow-id: flow-id, party: party })
    
    ;; Record event
    (record-event flow-id u"participant-del" u"Participant removed from workflow" none none)
    
    (ok true)))

;; Create assignment within workflow
(define-public (create-assignment
  (flow-id uint)
  (name (string-utf8 100))
  (detail (string-utf8 500))
  (operator (optional principal))
  (severity uint)
  (hours-needed uint)
  (start-block uint)
  (finish-block uint)
  (checkpoint-id (optional uint)))
  
  (let ((workflow-data (map-get? workflow-registry { flow-id: flow-id }))
        (assign-id (fetch-next-assign-id flow-id)))
    ;; Verify workflow existence
    (asserts! (is-some workflow-data) error-workflow-missing)
    
    ;; Verify authorization (operator level or higher)
    (asserts! (verify-access flow-id tx-sender perm-operator) error-not-permitted)
    
    ;; Verify checkpoint existence if provided
    (asserts! (or (is-none checkpoint-id) 
                 (is-some (map-get? checkpoint-registry { flow-id: flow-id, checkpoint-id: (unwrap-panic checkpoint-id) })))
            error-checkpoint-missing)
    
    ;; Create assignment
    (map-set assignment-tracking
      { flow-id: flow-id, assign-id: assign-id }
      {
        name: name,
        detail: detail,
        operator: operator,
        state: assign-state-pending,
        severity: severity,
        hours-needed: hours-needed,
        start-block: start-block,
        finish-block: finish-block,
        created-block: block-height,
        modified-block: block-height,
        checkpoint-id: checkpoint-id,
        output-hash: none
      })
    
    ;; Record event
    (record-event flow-id u"assign-create" u"New assignment created" (some assign-id) checkpoint-id)
    
    (ok assign-id)))

;; Update assignment details
(define-public (update-assignment
  (flow-id uint)
  (assign-id uint)
  (name (string-utf8 100))
  (detail (string-utf8 500))
  (operator (optional principal))
  (severity uint)
  (hours-needed uint)
  (start-block uint)
  (finish-block uint)
  (checkpoint-id (optional uint)))
  
  (let ((assignment-data (map-get? assignment-tracking { flow-id: flow-id, assign-id: assign-id })))
    ;; Verify assignment existence
    (asserts! (is-some assignment-data) error-assignment-missing)
    
    ;; Verify authorization (operator level or higher)
    (asserts! (or (verify-access flow-id tx-sender perm-operator)
                 (is-eq (get operator (unwrap-panic assignment-data)) (some tx-sender)))
            error-not-permitted)
    
    ;; Verify checkpoint existence if provided
    (asserts! (or (is-none checkpoint-id) 
                 (is-some (map-get? checkpoint-registry { flow-id: flow-id, checkpoint-id: (unwrap-panic checkpoint-id) })))
            error-checkpoint-missing)
    
    ;; Update assignment
    (map-set assignment-tracking
      { flow-id: flow-id, assign-id: assign-id }
      {
        name: name,
        detail: detail,
        operator: operator,
        state: (get state (unwrap-panic assignment-data)),
        severity: severity,
        hours-needed: hours-needed,
        start-block: start-block,
        finish-block: finish-block,
        created-block: (get created-block (unwrap-panic assignment-data)),
        modified-block: block-height,
        checkpoint-id: checkpoint-id,
        output-hash: (get output-hash (unwrap-panic assignment-data))
      })
    
    ;; Record event
    (record-event flow-id u"assign-update" u"Assignment modified" (some assign-id) checkpoint-id)
    
    (ok true)))

;; Change assignment state
(define-public (transition-assignment-state
  (flow-id uint)
  (assign-id uint)
  (new-state uint))
  
  (let ((assignment-data (map-get? assignment-tracking { flow-id: flow-id, assign-id: assign-id })))
    ;; Verify assignment existence
    (asserts! (is-some assignment-data) error-assignment-missing)
    
    ;; Verify authorization (operator level or higher)
    (asserts! (or (verify-access flow-id tx-sender perm-operator)
                 (is-eq (get operator (unwrap-panic assignment-data)) (some tx-sender)))
            error-not-permitted)
    
    ;; Validate state value
    (asserts! (and (>= new-state assign-state-pending) (<= new-state assign-state-cancelled)) error-state-invalid)
    
    ;; Check prerequisites if transitioning to active
    (asserts! (or (not (is-eq new-state assign-state-active))
                 (verify-prerequisites flow-id assign-id))
            error-chain-incomplete)
    
    ;; Update assignment state
    (map-set assignment-tracking
      { flow-id: flow-id, assign-id: assign-id }
      (merge (unwrap-panic assignment-data)
             {
               state: new-state,
               modified-block: block-height
             }))
    
    ;; Check if checkpoint should be updated
    (if (and (is-eq new-state assign-state-finished)
             (is-some (get checkpoint-id (unwrap-panic assignment-data))))
        (if (validate-checkpoint-ready flow-id (unwrap-panic (get checkpoint-id (unwrap-panic assignment-data))))
            (begin
              ;; Update checkpoint completion status
              (map-set checkpoint-registry
                { flow-id: flow-id, checkpoint-id: (unwrap-panic (get checkpoint-id (unwrap-panic assignment-data))) }
                (merge (unwrap-panic (map-get? checkpoint-registry 
                                              { flow-id: flow-id, checkpoint-id: (unwrap-panic (get checkpoint-id (unwrap-panic assignment-data))) }))
                       { complete: true }))
              
              ;; Record checkpoint completion
              (record-event flow-id u"checkpoint-done" u"Checkpoint completed" none (get checkpoint-id (unwrap-panic assignment-data)))
            )
            true
        )
        true
    )
    
    ;; Record event with state description
    (record-event flow-id u"assign-state" 
                 (concat u"Assignment state changed to " 
                        (if (is-eq new-state assign-state-pending) u"Pending"
                         (if (is-eq new-state assign-state-active) u"Active"
                          (if (is-eq new-state assign-state-under-review) u"Under Review"
                           (if (is-eq new-state assign-state-finished) u"Finished"
                            u"Cancelled"))))) 
                 (some assign-id) 
                 (get checkpoint-id (unwrap-panic assignment-data)))
    
    (ok true)))

;; Add dependency link between assignments
(define-public (establish-precedence
  (flow-id uint)
  (assign-id uint)
  (prior-assign-id uint))
  
  (let ((assignment-data (map-get? assignment-tracking { flow-id: flow-id, assign-id: assign-id }))
        (prior-assignment-data (map-get? assignment-tracking { flow-id: flow-id, assign-id: prior-assign-id })))
    ;; Verify assignments exist
    (asserts! (is-some assignment-data) error-assignment-missing)
    (asserts! (is-some prior-assignment-data) error-assignment-missing)
    
    ;; Verify authorization (admin level or higher)
    (asserts! (verify-access flow-id tx-sender perm-admin) error-not-permitted)
    
    ;; Prevent self-dependency
    (asserts! (not (is-eq assign-id prior-assign-id)) error-params-invalid)
    
    ;; Establish dependency
    (map-set precedence-tracking
      { flow-id: flow-id, assign-id: assign-id, prior-assign-id: prior-assign-id }
      { linked: true })
    
    ;; Record event
    (record-event flow-id u"precedence-add" 
                 u"Assignment dependency established" 
                 (some assign-id) 
                 none)
    
    (ok true)))

;; Remove dependency link between assignments
(define-public (dissolve-precedence
  (flow-id uint)
  (assign-id uint)
  (prior-assign-id uint))
  
  (let ((assignment-data (map-get? assignment-tracking { flow-id: flow-id, assign-id: assign-id })))
    ;; Verify assignment exists
    (asserts! (is-some assignment-data) error-assignment-missing)
    
    ;; Verify authorization (admin level or higher)
    (asserts! (verify-access flow-id tx-sender perm-admin) error-not-permitted)
    
    ;; Remove dependency
    (map-delete precedence-tracking
      { flow-id: flow-id, assign-id: assign-id, prior-assign-id: prior-assign-id })
    
    ;; Record event
    (record-event flow-id u"precedence-del" 
                 u"Assignment dependency removed" 
                 (some assign-id) 
                 none)
    
    (ok true)))

;; Attach deliverable reference to assignment
(define-public (attach-output
  (flow-id uint)
  (assign-id uint)
  (output-hash (buff 32)))
  
  (let ((assignment-data (map-get? assignment-tracking { flow-id: flow-id, assign-id: assign-id })))
    ;; Verify assignment exists
    (asserts! (is-some assignment-data) error-assignment-missing)
    
    ;; Verify authorization (operator level or higher)
    (asserts! (or (verify-access flow-id tx-sender perm-operator)
                 (is-eq (get operator (unwrap-panic assignment-data)) (some tx-sender)))
            error-not-permitted)
    
    ;; Update assignment with output
    (map-set assignment-tracking
      { flow-id: flow-id, assign-id: assign-id }
      (merge (unwrap-panic assignment-data)
             {
               output-hash: (some output-hash),
               modified-block: block-height
             }))
    
    ;; Record event
    (record-event flow-id u"output-attach" 
                 u"Deliverable attached to assignment" 
                 (some assign-id) 
                 (get checkpoint-id (unwrap-panic assignment-data)))
    
    (ok true)))

;; Record work effort on assignment
(define-public (report-work
  (flow-id uint)
  (assign-id uint)
  (hours-worked uint)
  (note-text (string-utf8 200)))
  
  (let ((assignment-data (map-get? assignment-tracking { flow-id: flow-id, assign-id: assign-id }))
        (record-id (fetch-next-work-record-id flow-id assign-id)))
    ;; Verify assignment exists
    (asserts! (is-some assignment-data) error-assignment-missing)
    
    ;; Verify authorization (participant status)
    (asserts! (has-participant-role flow-id tx-sender) error-not-permitted)
    
    ;; Record work effort
    (map-set work-records
      { flow-id: flow-id, assign-id: assign-id, record-id: record-id }
      {
        contributor: tx-sender,
        hours-worked: hours-worked,
        note-text: note-text,
        recorded-block: block-height
      })
    
    ;; Record event
    (record-event flow-id u"work-report" 
                 (concat u"Work hours recorded on assignment: " u"") 
                 (some assign-id) 
                 (get checkpoint-id (unwrap-panic assignment-data)))
    
    (ok record-id)))

;; Add discussion note to assignment
(define-public (write-note
  (flow-id uint)
  (assign-id uint)
  (message (string-utf8 500)))
  
  (let ((assignment-data (map-get? assignment-tracking { flow-id: flow-id, assign-id: assign-id }))
        (note-id (fetch-next-note-id flow-id assign-id)))
    ;; Verify assignment exists
    (asserts! (is-some assignment-data) error-assignment-missing)
    
    ;; Verify authorization (participant status)
    (asserts! (has-participant-role flow-id tx-sender) error-not-permitted)
    
    ;; Record note
    (map-set task-notes
      { flow-id: flow-id, assign-id: assign-id, note-id: note-id }
      {
        writer: tx-sender,
        message: message,
        written-block: block-height
      })
    
    ;; Record event
    (record-event flow-id u"note-write" 
                 u"Discussion note added to assignment" 
                 (some assign-id) 
                 (get checkpoint-id (unwrap-panic assignment-data)))
    
    (ok note-id)))

;; Create checkpoint milestone
(define-public (establish-checkpoint
  (flow-id uint)
  (name (string-utf8 100))
  (detail (string-utf8 500))
  (finish-block uint)
  (payout uint))
  
  (let ((workflow-data (map-get? workflow-registry { flow-id: flow-id }))
        (checkpoint-id (fetch-next-checkpoint-id flow-id)))
    ;; Verify workflow exists
    (asserts! (is-some workflow-data) error-workflow-missing)
    
    ;; Verify authorization (admin level or higher)
    (asserts! (verify-access flow-id tx-sender perm-admin) error-not-permitted)
    
    ;; Create checkpoint
    (map-set checkpoint-registry
      { flow-id: flow-id, checkpoint-id: checkpoint-id }
      {
        name: name,
        detail: detail,
        finish-block: finish-block,
        payout: payout,
        complete: false,
        settled: false
      })
    
    ;; Record event
    (record-event flow-id u"checkpoint-add" u"New checkpoint created" none (some checkpoint-id))
    
    (ok checkpoint-id)))
