import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from "https://deno.land/x/clarinet@v1.0.0/index.ts";
import { assertEquals } from "https://deno.land/std@0.90.0/testing/asserts.ts";

Clarinet.test({
  name: "Workflow creation succeeds with valid parameters",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Enterprise Task Hub"),
          types.utf8("Coordinate distributed team operations"),
          types.uint(100),
          types.uint(500),
          types.uint(50000)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result.expectOk(), types.uint(u1));
  }
});

Clarinet.test({
  name: "Query workflow returns correct structure after creation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Planning Phase"),
          types.utf8("Initial project scoping"),
          types.uint(200),
          types.uint(400),
          types.uint(25000)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "query-workflow",
        [types.uint(u1)],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    const result = block.receipts[0].result.expectSome();
    assertEquals(result.name, types.utf8("Planning Phase"));
  }
});

Clarinet.test({
  name: "Permission validation prevents unauthorized access modifications",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Team Coordination"),
          types.utf8("Multi-stakeholder project"),
          types.uint(150),
          types.uint(450),
          types.uint(60000)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "update-workflow",
        [
          types.uint(u1),
          types.utf8("Updated Title"),
          types.utf8("Updated description"),
          types.uint(2),
          types.uint(160),
          types.uint(460),
          types.uint(65000)
        ],
        wallet1.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectErr(), types.uint(u100));
  }
});

Clarinet.test({
  name: "Participant enrollment establishes team membership",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Multi-team Initiative"),
          types.utf8("Cross-functional collaboration"),
          types.uint(100),
          types.uint(600),
          types.uint(80000)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "enroll-participant",
        [
          types.uint(u1),
          types.principal(wallet1.address),
          types.uint(3)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
  }
});

Clarinet.test({
  name: "Duplicate participant enrollment is rejected",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Project X"),
          types.utf8("Critical initiative"),
          types.uint(50),
          types.uint(550),
          types.uint(100000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "enroll-participant",
        [
          types.uint(u1),
          types.principal(wallet1.address),
          types.uint(3)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "enroll-participant",
        [
          types.uint(u1),
          types.principal(wallet1.address),
          types.uint(2)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectErr(), types.uint(u106));
  }
});

Clarinet.test({
  name: "Permission reassignment updates access level correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("HR Operations"),
          types.utf8("Personnel management system"),
          types.uint(75),
          types.uint(525),
          types.uint(40000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "enroll-participant",
        [
          types.uint(u1),
          types.principal(wallet1.address),
          types.uint(4)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "reassign-participant-role",
        [
          types.uint(u1),
          types.principal(wallet1.address),
          types.uint(3)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
  }
});

Clarinet.test({
  name: "Assignment creation within workflow succeeds with authorization",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Development Sprint"),
          types.utf8("Feature implementation cycle"),
          types.uint(125),
          types.uint(425),
          types.uint(75000)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Backend API Development"),
          types.utf8("RESTful service endpoints"),
          types.some(types.principal(deployer.address)),
          types.uint(2),
          types.uint(40),
          types.uint(130),
          types.uint(270),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result.expectOk(), types.uint(u1));
  }
});

Clarinet.test({
  name: "Assignment query retrieves accurate data",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("QA Cycle"),
          types.utf8("Quality assurance validation"),
          types.uint(200),
          types.uint(350),
          types.uint(30000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Test Case Authoring"),
          types.utf8("Create comprehensive test scenarios"),
          types.none(),
          types.uint(1),
          types.uint(20),
          types.uint(210),
          types.uint(240),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "query-assignment",
        [types.uint(u1), types.uint(u1)],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    const result = block.receipts[0].result.expectSome();
    assertEquals(result.name, types.utf8("Test Case Authoring"));
  }
});

Clarinet.test({
  name: "Assignment state transition validates prerequisites",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Production Release"),
          types.utf8("Deployment preparation"),
          types.uint(90),
          types.uint(510),
          types.uint(55000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("System Testing"),
          types.utf8("End-to-end validation"),
          types.some(types.principal(deployer.address)),
          types.uint(3),
          types.uint(35),
          types.uint(100),
          types.uint(300),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "transition-assignment-state",
        [
          types.uint(u1),
          types.uint(u1),
          types.uint(2)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
  }
});

Clarinet.test({
  name: "Invalid state value is rejected during transition",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Analytics Platform"),
          types.utf8("Data processing system"),
          types.uint(60),
          types.uint(540),
          types.uint(90000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Dashboard Creation"),
          types.utf8("Build visualization layer"),
          types.some(types.principal(deployer.address)),
          types.uint(2),
          types.uint(30),
          types.uint(70),
          types.uint(280),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "transition-assignment-state",
        [
          types.uint(u1),
          types.uint(u1),
          types.uint(99)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectErr(), types.uint(u104));
  }
});

Clarinet.test({
  name: "Deliverable attachment captures output reference",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Content Creation"),
          types.utf8("Document generation"),
          types.uint(110),
          types.uint(410),
          types.uint(35000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Technical Documentation"),
          types.utf8("Write API specifications"),
          types.some(types.principal(deployer.address)),
          types.uint(2),
          types.uint(25),
          types.uint(115),
          types.uint(260),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "attach-output",
        [
          types.uint(u1),
          types.uint(u1),
          types.buff(
            "0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
          )
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
  }
});

Clarinet.test({
  name: "Work effort reporting records contribution hours",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Training Initiative"),
          types.utf8("Employee skill development"),
          types.uint(80),
          types.uint(480),
          types.uint(20000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Course Material Preparation"),
          types.utf8("Develop training content"),
          types.some(types.principal(deployer.address)),
          types.uint(1),
          types.uint(16),
          types.uint(85),
          types.uint(250),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "report-work",
        [
          types.uint(u1),
          types.uint(u1),
          types.uint(8),
          types.utf8("Completed initial draft")
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.uint(u1));
  }
});

Clarinet.test({
  name: "Discussion notes accumulate on assignments",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Infrastructure Updates"),
          types.utf8("System modernization project"),
          types.uint(170),
          types.uint(370),
          types.uint(120000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Database Migration"),
          types.utf8("Upgrade database infrastructure"),
          types.some(types.principal(deployer.address)),
          types.uint(3),
          types.uint(50),
          types.uint(180),
          types.uint(330),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "write-note",
        [
          types.uint(u1),
          types.uint(u1),
          types.utf8("Backup strategy finalized, proceeding with migration")
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.uint(u1));
  }
});

Clarinet.test({
  name: "Checkpoint creation establishes milestone reference",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Enterprise Transformation"),
          types.utf8("Digital modernization initiative"),
          types.uint(40),
          types.uint(560),
          types.uint(500000)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "establish-checkpoint",
        [
          types.uint(u1),
          types.utf8("Phase One Completion"),
          types.utf8("Foundation and infrastructure ready"),
          types.uint(250),
          types.uint(50000)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.uint(u1));
  }
});

Clarinet.test({
  name: "Assignment dependency prevents state transition to active",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Sequential Tasks"),
          types.utf8("Ordered workflow execution"),
          types.uint(30),
          types.uint(570),
          types.uint(45000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Task A"),
          types.utf8("First task"),
          types.none(),
          types.uint(1),
          types.uint(10),
          types.uint(35),
          types.uint(265),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Task B"),
          types.utf8("Second task"),
          types.none(),
          types.uint(1),
          types.uint(15),
          types.uint(40),
          types.uint(270),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "establish-precedence",
        [
          types.uint(u1),
          types.uint(u2),
          types.uint(u1)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "transition-assignment-state",
        [
          types.uint(u1),
          types.uint(u2),
          types.uint(2)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectErr(), types.uint(u109));
  }
});

Clarinet.test({
  name: "Circular self-dependency is prevented",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Cycle Prevention"),
          types.utf8("Guard against circular references"),
          types.uint(140),
          types.uint(390),
          types.uint(15000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Standalone Work"),
          types.utf8("Independent task"),
          types.none(),
          types.uint(1),
          types.uint(12),
          types.uint(145),
          types.uint(255),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "establish-precedence",
        [
          types.uint(u1),
          types.uint(u1),
          types.uint(u1)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectErr(), types.uint(u108));
  }
});

Clarinet.test({
  name: "Authorized users can remove assignment dependencies",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "setup-workflow",
        [
          types.utf8("Dependency Management"),
          types.utf8("Link and unlink tasks"),
          types.uint(105),
          types.uint(435),
          types.uint(22000)
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Task X"),
          types.utf8("First work item"),
          types.none(),
          types.uint(1),
          types.uint(8),
          types.uint(110),
          types.uint(240),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "create-assignment",
        [
          types.uint(u1),
          types.utf8("Task Y"),
          types.utf8("Second work item"),
          types.none(),
          types.uint(1),
          types.uint(6),
          types.uint(120),
          types.uint(245),
          types.none()
        ],
        deployer.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "establish-precedence",
        [
          types.uint(u1),
          types.uint(u2),
          types.uint(u1)
        ],
        deployer.address
      )
    ]);
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "process-orchestrator",
        "dissolve-precedence",
        [
          types.uint(u1),
          types.uint(u2),
          types.uint(u1)
        ],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
  }
});
