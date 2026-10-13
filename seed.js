/* Starting data for Project AHA, used when the tracker opens with no saved data
   in this browser. The shared (hosted) tracker keeps its data in its own database. */
(function () {
  const uid = () => (crypto.randomUUID ? crypto.randomUUID() : 'id-' + Date.now().toString(36) + Math.random().toString(36).slice(2));
  function buildSeed() {
    const now = new Date().toISOString();
    const db = { version: 1, initiatives: [], items: [] };
    const addInit = (name, description) => {
      const it = { id: uid(), name, description, order: db.initiatives.length, createdAt: now };
      db.initiatives.push(it); return it.id;
    };
    // Adds an item; `children` is an array of [name, status, children?] tuples.
    const addItem = (initiativeId, parentId, name, status, children, order) => {
      const item = { id: uid(), initiativeId, parentId, name, status: status || 'Thoughts', deadline: '', owner: '', notes: '', links: [], order, createdAt: now, updatedAt: now };
      db.items.push(item);
      (children || []).forEach((c, i) => addItem(initiativeId, item.id, c[0], c[1], c[2], i));
      return item.id;
    };
    const addTracks = (initId, tracks) => tracks.map((t, i) => addItem(initId, null, t[0], t[1], t[2], i));
  
    const orion = addInit('ORION', 'Budgeting, projection & utilisation platform');
    const polaris = addInit('POLARIS', 'Debt management, fees & reconciliation');
    const payment = addInit('Payment Transformation', 'End-to-end payment process redesign');
  
    addTracks(orion, [
      ['Medium Term Projection (MTP)', null, [
        ['Recalculation of SOF', 'IT Testing'],
        ['MTP Variance after refactoring', 'IT Testing'],
        ['MTP Broken Linkage (Mainstreaming)', 'Developing'],
      ]],
      ['Annual Budget', null, [
        ['When to port Annual Budget line over to MTP (after Fin Supported?)', 'Planning'],
        ['Include column in Raw Report: Budgeted amount after DY Supported, before Clarification', 'Planning'],
      ]],
      ['Block Budget', null, [
        ['Refactoring of Block Budget', 'Developing'],
        ['Block Budget Raw Report', 'IT Testing'],
        ['Block Budget Report', 'IT Testing'],
        ['Block Budget Variance Report', 'IT Testing'],
        ['Block Budget Projection Parameter', 'Developing'],
      ]],
      ['Expenditure & Utilisation', null, [
        ['Uploading of Expenditure GL', 'User Testing'],
        ['Calculation of Project Utilisation', 'User Testing'],
        ['Calculation of individual line utilisation', 'Pending User'],
        ['Provide expenditure access to specific Branch Rep (tag to BR Account)', 'Developing'],
        ['AOR', 'User Testing'],
      ]],
      ['Dashboard', null, [
        ['Outstanding To Do Items', 'IT Testing'],
        ['Project Budget', 'IT Testing'],
        ['Project Expenditure & Utilisation', 'IT Testing'],
        ['Individual lines budget by Branch', 'Thoughts'],
        ['Individual lines Expenditure & Utilisation', 'Thoughts'],
        ['Customisation of Tables', 'Thoughts'],
        ['ServiceNow Error Issue', 'Developing'],
      ]],
      ['Post Feedback Iterations', null, [
        ['Email Notification', 'Planning'],
        ['Force Refresh of Page', 'Developing'],
        ['Shift view for Reviewers and Approvals', 'Planning'],
        ['Justification of Variance Link', 'Developing'],
      ]],
    ]);
  
    const [debt] = addTracks(polaris, [
      ['Debt Management', null, [
        ['Pulling of data on Debt Records', 'Thoughts'],
        ['List of Debt Records', null, [
          ['List of Debt Records', 'Completed'],
          ['Debtor Report', 'Completed'],
          ['Arrears Report', 'Completed'],
          ['Written Off Report', 'Completed'],
          ['To Be Written Off Report', 'Completed'],
          ['Call for Return', 'Completed'],
        ]],
        ['Payments', 'Thoughts', [
          ['Monthly Giro deduction', 'Thoughts'],
        ]],
        ['Reconciliation', 'Thoughts'],
        ['Debt Management Dashboard', 'Thoughts'],
      ]],
      ['Fees & Maintenance', 'Thoughts'],
      ['Reconciliation', 'Thoughts'],
    ]);
    // POLARIS 1c Payments is also relevant to Payment Transformation.
    const payments = db.items.find(i => i.parentId === debt && i.name === 'Payments');
    if (payments) payments.links = [payment];
  
    addTracks(payment, [
      ['Payment before Permit Approval', 'Pending User'],
    ]);
    return db;
  }
  window.ahaBuildSeed = buildSeed;
})();
