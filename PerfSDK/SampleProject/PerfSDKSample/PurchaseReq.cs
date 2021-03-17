using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.ObjectModel;
using MS.Dynamics.TestTools.CloudCommonTestUtilities.Authentication;
using MS.Dynamics.TestTools.CloudCommonTestUtilities.Enums;
using Microsoft.Dynamics.TestTools.Dispatcher.Client;
using MS.Dynamics.TestTools.DispatcherProxyLibrary.ApplicationForms;
using MS.Dynamics.Performance.Framework.TaskRecorder;
using MS.Dynamics.TestTools.CloudCommonTestUtilities;
using System.IO;

namespace MS.Dynamics.Performance.Application.SCM
{
    /// <summary>
    /// PDL test for create purchase requisition
    /// </summary>
    [TestClass]
    public sealed class CreatePurchReqBase
    {
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
            _userContext.Dispose();
        }

        private DispatchedClient Client;
        private UserContext _userContext;
        /// <summary>
        /// TestSetup
        /// </summary>
        [TestInitialize]
        public void TestSetup()
        {
            SetupData();
            _userContext = new UserContext(UserManagement.AdminUser);
        }

        private void SetupClient(DispatchedClient _client)
        {
            Client = _client;
            Client.ForceEditMode = false;
            Client.Company = WellKnownCompanyID.USMF.ToString();
            Client.Open();
        }

        private ClientContext CreateClientContext()
        {
            return ClientContext.Create(Client);
        }

        private string PurchReqCreate_PurchReqTable_PurchReqName;
        private Collection<object> PurchReqAddItem_GridItemCatalog_GridItemCatalog;
        private Collection<object> PurchReqAddItem_GridItemCatalog_GridItemCatalog1;
        /// <summary>
        /// PDL for Create Purchase Requisition with 2 catalog lines
        /// In Contoso data set, the 2 items are 1003 and #9
        /// </summary>
        [TestMethod]
        public void CreatePurchReq()
        {
            SetupClient(DispatchedClient.DefaultInstance);
            RunCreatePurchReqTest();
        }

        private void RunCreatePurchReqTest()
        {
            using (var c = this.CreateClientContext())
            {
                using (var c1 = c.Navigate<PurchReqTableListPage>("purchreqtableall"))
                {
                    PurchReqTableListPage PurchReqTableListPageFormInstance = c1.Form<PurchReqTableListPage>();
                    using (var c2 = c1.Action("SystemDefinedNewButton_Click"))
                    {
                        Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.CommandButtonControl.Attach(PurchReqTableListPageFormInstance, "SystemDefinedNewButton").Click();
                        using (var c3 = c2.Attach<PurchReqCreate>())
                        {
                            PurchReqCreate PurchReqCreateFormInstance = c3.Form<PurchReqCreate>();
                            PurchReqCreateFormInstance.PurchReqTable_PurchReqName.SetValue(PurchReqCreate_PurchReqTable_PurchReqName);
                            using (var c4 = c3.Action("OK_Click"))
                            {
                                PurchReqCreateFormInstance.OK.Click();
                                using (var c5 = c4.Attach<PurchReqTable>())
                                {
                                    PurchReqTable PurchReqTableFormInstance = c5.Form<PurchReqTable>();
                                    using (var c6 = c5.Action("PurchReqTable_BusinessJustification_PurchReqTable_BusinessJustification_Description_RequestPopup"))
                                    {
                                        PurchReqTableFormInstance.PurchReqTable_BusinessJustification_Description.OpenLookup();
                                        using (var c7 = c6.AttachPrivate(""))
                                        {
                                            DispatchedForm PurchReqTable_BusinessJustification_LookupFormInstance = c7.DispatchedForm; //.Form();
                                            Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.GridControl.Attach(PurchReqTable_BusinessJustification_LookupFormInstance, "Grid").SelectRecord();
                                        }
                                    }

                                    using (var c8 = c5.Action("PurchReqAddItem_Click"))
                                    {
                                        PurchReqTableFormInstance.PurchReqAddItem.Click();
                                        using (var c9 = c8.Attach<PurchReqAddItem>())
                                        {
                                            PurchReqAddItem PurchReqAddItemFormInstance = c9.Form<PurchReqAddItem>();
                                            using (var c10 = c9.Action("GridItemCatalog_ChangeSelectedIndex"))
                                            {
                                                PurchReqAddItemFormInstance.GridItemCatalog.ChangeRow(PurchReqAddItem_GridItemCatalog_GridItemCatalog[0].ToString());
                                                PurchReqAddItemFormInstance.ButtonAddItem.Click();
                                                PurchReqAddItemFormInstance.GridItemCatalog.ChangeRow(PurchReqAddItem_GridItemCatalog_GridItemCatalog1[0].ToString());
                                                PurchReqAddItemFormInstance.ButtonAddItem.Click();
                                            }
                                            PurchReqAddItemFormInstance.Ok.Click();
                                        }
                                    }

                                    Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.CommandButtonControl.Attach(PurchReqTableFormInstance, "SystemDefinedSaveButton").Click();
                                }
                            }
                        }
                    }
                }
            }
        }

        private void SetupData()
        {
            PurchReqCreate_PurchReqTable_PurchReqName = "nn";
            PurchReqAddItem_GridItemCatalog_GridItemCatalog = new Collection<object>(new[] { "0" });
            PurchReqAddItem_GridItemCatalog_GridItemCatalog1 = new Collection<object>(new[] { "1" });
        }
    }
}
