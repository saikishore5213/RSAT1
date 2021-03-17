using Microsoft.Dynamics.TestTools.Dispatcher.Client;
using Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MS.Dynamics.Performance.Framework;
using MS.Dynamics.Performance.Framework.TaskRecorder;
using MS.Dynamics.TestTools.CloudCommonTestUtilities;
using MS.Dynamics.TestTools.CloudCommonTestUtilities.Enums;
using MS.Dynamics.TestTools.DispatcherProxyLibrary.ApplicationForms;
using MS.Dynamics.TestTools.UIHelpers.Core;
using System;
using System.Threading;
using System.IO;

namespace MS.Dynamics.Performance.Application.GFM.PDLTrend
{
    [TestClass]
    public sealed class ProcureToPayTrend
    {
        private const int minThinkTime = 15000;
        private const int maxThinkTime = 30000;

        private void InsertThinkTime()
        {
            bool useThinkTime = DispatchedClientHelper.GetTestContextPropertyValue<bool>("UseThinkTime", this.TestContext, true);
            if (useThinkTime)
            {
                int sleepTime = RandomNum.GetNext(minThinkTime, maxThinkTime);
                Thread.Sleep(sleepTime);
            }
        }

        /// <summary>
        /// Procurement to Payment trend run scenario
        /// Test will only run on the performance volumedata
        /// </summary>
        [TestMethod]
        public void ProcureToPaymentTrend()
        {
            DispatchedClientHelper helper = new DispatchedClientHelper();
            Client = helper.GetClient();
            Client.ForceEditMode = false;
            Client.Company = WellKnownCompanyID.USMF.ToString();
            Client.Open();
            ProcureToPayTest();
        }

        /// <summary>
        /// Gets the test context. Use the property for setting test transactions in the performance tests.
        /// </summary>
        public TestContext TestContext
        {
            get;
            set;
        }

        /// <summary>
        /// TestCleanup
        /// </summary>
        [TestCleanup]
        public void TestCleanup()
        {
            Client.Close();
            Client.Dispose();
            Client = null;
        }

        private DispatchedClient Client;
        private TimerProvider timerProvider;

        /// <summary>
        /// TestSetup
        /// </summary>
        [TestInitialize]
        public void TestSetup()
        {
            bool useDetailedTimer = DispatchedClientHelper.GetTestContextPropertyValue<bool>("UseDetailedTimer", this.TestContext, false);
            if (useDetailedTimer && this.TestContext != null)
            {
                timerProvider = new TimerProvider(this.TestContext);
            }
            SetupData();
        }

        private ClientContext CreateClientContext()
        {
            if (timerProvider != null)
            {
                return ClientContext.Create(Client, timerProvider.OnBeginTimer, timerProvider.OnEndTimer);
            }

            return ClientContext.Create(Client);
        }

        #region Performance Variability

        private RandomRange RandomNum = new RandomRange();

        private string GetRandomVendorId()
        {
            return RandomNum.GetNext("V", 1, 100000);
        }

        private string GetRandomItemId()
        {
            return RandomNum.GetNext("E", 100001, 200000);
        }

        #endregion

        private string PurchTable_PurchLine_ItemId1;
        private decimal PurchTable_PurchLine_PurchQtyGrid1;
        private string PurchTable_PurchLine_ItemId2;
        private decimal PurchTable_PurchLine_PurchQtyGrid2;
        private string PurchTable_PurchLine_ItemId3;
        private decimal PurchTable_PurchLine_PurchQtyGrid3;
        private string PurchTable_PurchLine_ItemId4;
        private decimal PurchTable_PurchLine_PurchQtyGrid4;
        private string PurchTable_PurchLine_ItemId5;
        private decimal PurchTable_PurchLine_PurchQtyGrid5;
        private string PurchTable_PurchLine_ItemId6;
        private decimal PurchTable_PurchLine_PurchQtyGrid6;
        private string PurchTable_PurchLine_ItemId7;
        private decimal PurchTable_PurchLine_PurchQtyGrid7;
        private string PurchTable_PurchLine_ItemId8;
        private decimal PurchTable_PurchLine_PurchQtyGrid8;
        private string PurchTable_PurchLine_ItemId9;
        private decimal PurchTable_PurchLine_PurchQtyGrid9;
        private string PurchTable_PurchLine_ItemId10;
        private decimal PurchTable_PurchLine_PurchQtyGrid10;
        private string PurchEditLines_PurchParmTable_Num;
        private string VendEditInvoice_PurchParmTable_Num;
        private PurchOrderMaintainWorkspace PurchOrderMaintainWorkspaceForm;
        private PurchTable PurchTableFormInstance;

        void ProcureToPayTest()
        {
            using (var c = this.CreateClientContext())
            {
                this.SetBatchTransferRuleForSubledgerJournalAccountEntriesToBatch();
                InsertThinkTime();
                ScopedTimer openWorkspace = new ScopedTimer(TestContext, "Navigate to PurchOrderMaintainWorkspace");
                using (var cw = c.Navigate<PurchOrderMaintainWorkspace>("purchordermaintainworkspace", Microsoft.Dynamics.TestTools.Dispatcher.MenuItemType.Display))
                {
                    PurchOrderMaintainWorkspaceForm = cw.Form<PurchOrderMaintainWorkspace>();
                    openWorkspace.Dispose();

                    InsertThinkTime();
                    ScopedTimer openAllPO = new ScopedTimer(TestContext, "Open All Purchase Orders Tile");
                    using (var cl = cw.Action("PurchTableTile_Click"))
                    {
                        PurchOrderMaintainWorkspaceForm.PurchTableTile.Click();
                        using (var c1 = cl.Attach<PurchTable>())
                        {
                            PurchTableFormInstance = c1.Form<PurchTable>();
                            openAllPO.Dispose();

                            InsertThinkTime();
                            ScopedTimer createHeader = new ScopedTimer(TestContext, "Create Header");

                            using (var c2 = c1.Action("SystemDefinedNewButton_Click"))
                            {
                                Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.CommandButtonControl.Attach(PurchTableFormInstance, "SystemDefinedNewButton").Click();
                                using (var c3 = c2.Attach<PurchCreateOrder>())
                                {
                                    PurchCreateOrder PurchCreateOrderFormInstance = c3.Form<PurchCreateOrder>();
                                    PurchCreateOrderFormInstance.PurchTable_OrderAccount.SetValue(GetRandomVendorId());
                                    PurchCreateOrderFormInstance.OK.Click();
                                }

                                using (var c6 = c2.Attach<PurchTable>())
                                {
                                    PurchTableFormInstance = c6.Form<PurchTable>();

                                    createHeader.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line1 = new ScopedTimer(TestContext, "Create Line 1");

                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId1);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid1);

                                    line1.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line2 = new ScopedTimer(TestContext, "Create Line 2");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId2);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid2);

                                    line2.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line3 = new ScopedTimer(TestContext, "Create Line 3");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId3);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid3);

                                    line3.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line4 = new ScopedTimer(TestContext, "Create Line 4");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId4);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid4);

                                    line4.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line5 = new ScopedTimer(TestContext, "Create Line 5");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId5);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid5);

                                    line5.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line6 = new ScopedTimer(TestContext, "Create Line 6");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId6);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid6);

                                    line6.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line7 = new ScopedTimer(TestContext, "Create Line 7");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId7);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid7);

                                    line7.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line8 = new ScopedTimer(TestContext, "Create Line 8");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId8);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid8);

                                    line8.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line9 = new ScopedTimer(TestContext, "Create Line 9");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId9);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid9);

                                    line9.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer line10 = new ScopedTimer(TestContext, "Create Line 10 and save");

                                    PurchTableFormInstance.LineStripNew.Click();
                                    PurchTableFormInstance.PurchLine_ItemId.SetValue(PurchTable_PurchLine_ItemId10);
                                    PurchTableFormInstance.PurchLine_PurchQtyGrid.SetValue(PurchTable_PurchLine_PurchQtyGrid10);

                                    Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.CommandButtonControl.Attach(PurchTableFormInstance, "SystemDefinedSaveButton").Click();

                                    line10.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer purchConfirm = new ScopedTimer(TestContext, "Purchase Confirm");

                                    PurchTableFormInstance.Purchase.Activate();
                                    PurchTableFormInstance.ButtonConfirm.Click();

                                    purchConfirm.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer updateReceipts = new ScopedTimer(TestContext, "Update Receipts List");

                                    PurchTableFormInstance.Receive.Activate();
                                    using (var c7 = c6.Action("buttonUpdateReceiptsList_Click"))
                                    {
                                        PurchTableFormInstance.ButtonUpdateReceiptsList.Click();
                                        using (var c8 = c7.Attach<PurchEditLines>())
                                        {
                                            PurchEditLines PurchEditLinesFormInstance = c8.Form<PurchEditLines>();
                                            PurchEditLinesFormInstance.OK.Click();
                                        }
                                    }

                                    updateReceipts.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer updatePackingSlip = new ScopedTimer(TestContext, "Update Packing Slip");

                                    PurchTableFormInstance.Receive.Activate();
                                    using (var c9 = c6.Action("buttonUpdatePackingSlip_Click"))
                                    {
                                        PurchTableFormInstance.ButtonUpdatePackingSlip.Click();
                                        using (var c10 = c9.Attach<PurchEditLines>())
                                        {
                                            PurchEditLines PurchEditLinesFormInstance1 = c10.Form<PurchEditLines>();
                                            PurchEditLinesFormInstance1.PurchParmTable_Num.SetValue(PurchEditLines_PurchParmTable_Num);
                                            PurchEditLinesFormInstance1.OK.Click();
                                        }
                                    }

                                    updatePackingSlip.Dispose();
                                    InsertThinkTime();
                                    ScopedTimer updateInvoice = new ScopedTimer(TestContext, "Invoice PO");

                                    PurchTableFormInstance.Invoice.Activate();
                                    using (var c11 = c6.Action("buttonUpdateInvoice_Click"))
                                    {
                                        PurchTableFormInstance.ButtonUpdateInvoice.Click();
                                        using (var c12 = c11.Attach<VendEditInvoice>())
                                        {
                                            VendEditInvoice VendEditInvoiceFormInstance = c12.Form<VendEditInvoice>();
                                            VendEditInvoiceFormInstance.PurchParmTable_Num.SetValue(VendEditInvoice_PurchParmTable_Num);
                                            Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.CommandButtonControl.Attach(VendEditInvoiceFormInstance, "SystemDefinedSaveButton").Click();
                                            using (var c13 = c12.Action("OK_RequestPopup"))
                                            {
                                                VendEditInvoiceFormInstance.OK.Click();
                                                using (var c14 = c13.Attach<VendEditInvoicePostDropDialog>())
                                                {
                                                    VendEditInvoicePostDropDialog VendEditInvoicePostDropDialogFormInstance = c14.Form<VendEditInvoicePostDropDialog>();
                                                    VendEditInvoicePostDropDialogFormInstance.OKButton.Click();
                                                }
                                            }
                                        }
                                    }

                                    updateInvoice.Dispose();
                                }
                            }
                        }
                    }
                }
            }
        }

        private void SetupData()
        {
            PurchTable_PurchLine_ItemId1 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid1 = 10m;
            PurchTable_PurchLine_ItemId2 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid2 = 10m;
            PurchTable_PurchLine_ItemId3 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid3 = 10m;
            PurchTable_PurchLine_ItemId4 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid4 = 10m;
            PurchTable_PurchLine_ItemId5 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid5 = 10m;
            PurchTable_PurchLine_ItemId6 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid6 = 10m;
            PurchTable_PurchLine_ItemId7 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid7 = 10m;
            PurchTable_PurchLine_ItemId8 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid8 = 10m;
            PurchTable_PurchLine_ItemId9 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid9 = 10m;
            PurchTable_PurchLine_ItemId10 = GetRandomItemId();
            PurchTable_PurchLine_PurchQtyGrid10 = 10m;
            PurchEditLines_PurchParmTable_Num = Guid.NewGuid().ToString();
            VendEditInvoice_PurchParmTable_Num = Guid.NewGuid().ToString();
        }
        private void SetBatchTransferRuleForSubledgerJournalAccountEntriesToBatch()
        {
            using (LedgerParameters ledgerParameters = LedgerParameters.Open(Client))
            {
                if (ledgerParameters.SubledgerJournalTransferRules.MoveTo(ledgerParameters.RuleType, 0))
                {
                    ledgerParameters.TransferMode.SetValue(TestTools.DispatcherProxyLibrary.ApplicationEnums.SubledgerJournalTransferMode.ScheduledBatch);
                    ledgerParameters.Save();
                }
            }
        }
    }
}
